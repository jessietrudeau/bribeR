# data-raw/build_transcript_index.R
#
# Builds `transcript_index`: one row per transcript, holding its metadata and
# summary from Descriptions.csv alongside 0/1 indicator columns for every
# speaker and every topic, which is what get_transcript_id() filters on.

# ---- setup ----
required_pkgs <- c("fs", "dplyr", "stringr", "tools", "readr", "purrr", "lubridate", "tidyr", "stringi")
to_install <- setdiff(required_pkgs, rownames(installed.packages()))
if (length(to_install)) install.packages(to_install, repos = "https://cloud.r-project.org")

library(fs)
library(dplyr)
library(stringr)
library(tools)
library(readr)
library(purrr)
library(lubridate)
library(tidyr)

# Speaker identifiers are matched lowercased, whitespace-squished and stripped
# of diacritics, so that the roster, the transcripts and speakers.csv all resolve
# to the same key.
.norm_key <- function(x) {
  stringi::stri_trans_general(str_to_lower(str_squish(str_trim(as.character(x)))), "Latin-ASCII")
}

# ---- configuration ----
transcripts_candidates <- c(
  Sys.getenv("TRANSCRIPTS_DIR", unset = NA),
  "inst/data-raw/transcripts"
) |> unique()
transcripts_candidates <- transcripts_candidates[!is.na(transcripts_candidates)]
transcripts_root <- transcripts_candidates[dir_exists(transcripts_candidates)][1]
if (is.na(transcripts_root)) {
  stop("No transcripts directory found. Checked: ", paste(transcripts_candidates, collapse = " | "))
}
# ---- list transcript files ----
files <- dir_ls(
  transcripts_root, recurse = TRUE, type = "file",
  regexp = "(?i)\\.csv$"
)
if (length(files) == 0L) stop("No transcript files found under: ", transcripts_root)

# Sort by the numeric filename, falling back to alphabetical if any name is not a number
base_ids <- tools::file_path_sans_ext(path_file(files))
nums <- suppressWarnings(as.integer(base_ids))
ord <- if (all(!is.na(nums))) order(nums) else order(base_ids)
files <- files[ord]

# ---- load Descriptions.csv ----
# It supplies each transcript's date, summary, type and topic flags, which are
# folded into `transcript_index` below rather than shipped as their own dataset.
desc_candidates <- c(
  Sys.getenv("DESCRIPTIONS_CSV", unset = NA),
  "data-raw/Inventory & Descriptions/Descriptions.csv"
) |> unique()
desc_candidates <- desc_candidates[!is.na(desc_candidates)]
desc_path <- desc_candidates[file_exists(desc_candidates)][1]
if (is.na(desc_path)) {
  stop("descriptions.csv not found. Checked: ", paste(desc_candidates, collapse = " | "))
}
descriptions_df <- read_csv(desc_path, show_col_types = FALSE)

message("Using descriptions from: ", desc_path)

# Helper: convert a raw "x"/NA (or blank) character flag to integer 0/1.
.to_flag <- function(x) {
  if (is.numeric(x) || is.integer(x)) return(as.integer(!is.na(x) & x != 0L))
  as.integer(!is.na(x) & grepl("^\\s*x\\s*$", as.character(x), ignore.case = TRUE))
}

# ---- identify and convert topic columns to binary ----
topic_cols <- grep("(?i)^topic", names(descriptions_df), value = TRUE)
message("Detected ", length(topic_cols), " topic columns.")
if (length(topic_cols) > 0) {
  descriptions_df <- descriptions_df |>
    mutate(across(all_of(topic_cols), .to_flag))
} else {
  message("⚠️ No topic columns found. Check column names in descriptions.csv.")
}

# ---- prepare metadata (n + date + topics) ----
metadata_df <- descriptions_df |>
  mutate(
    n = suppressWarnings(as.integer(n)),
    date = suppressWarnings(parse_date_time(
      date,
      orders = c(
        "Y-m-d", "Y/m/d", "Ymd",
        "m/d/Y", "m-d-Y", "mdY",
        "d/m/Y", "d-m-Y", "dmY",
        "d b Y", "d B Y", "b d Y", "B d Y",
        "Y b d", "Y B d", "b Y", "B Y", "Y"
      ),
      tz = "UTC"
    ) |> as.Date()),
    in_book           = .to_flag(in_book),
    in_online_archive = .to_flag(in_online_archive),
    original_id       = as.character(original_n)
  ) |>
  select(n, original_id, date, in_book, in_online_archive, type, summary, speakers, all_of(topic_cols)) |>
  filter(!is.na(n))

# ---- speakers per transcript, derived from the dialogue ----
# A speaker is anyone the transcript attributes at least one turn to, so
# presence is read straight from the transcript files. "background" carries
# stage directions rather than speech and is excluded.
message("Deriving speaker presence from the transcript files...")

speaker_table <- map_dfr(files, function(path) {
  df <- read_csv(path, show_col_types = FALSE, progress = FALSE)
  if (!"speaker_std" %in% names(df)) {
    return(tibble(n = integer(), speaker_key = character()))
  }
  tibble(
    n = as.integer(tools::file_path_sans_ext(path_file(path))),
    speaker_key = .norm_key(df$speaker_std)
  )
}) |>
  filter(!is.na(speaker_key), speaker_key != "", speaker_key != "background") |>
  distinct(n, speaker_key)


# Build binary matrix of speaker presence per transcript
speaker_matrix <- speaker_table |>
  mutate(value = 1L) |>
  pivot_wider(
    id_cols = n,
    names_from = speaker_key,
    values_from = value,
    values_fill = list(value = 0L),
    names_prefix = "speaker_"
  )

message("Constructed speaker matrix (",
        nrow(speaker_matrix), " transcripts; ",
        length(grep('^speaker_', names(speaker_matrix))), " unique speakers).")

# ---- load speakers.csv and filter speaker columns ----
speakers_candidates <- c(
  Sys.getenv("SPEAKERS_CSV", unset = NA),
  "data-raw/Inventory & Descriptions/speakers.csv"
) |> unique()
speakers_candidates <- speakers_candidates[!is.na(speakers_candidates)]
speakers_path <- speakers_candidates[file_exists(speakers_candidates)][1]

if (!is.na(speakers_path)) {
  message("Using speaker roster from: ", speakers_path)
  speakers_df <- read_csv(speakers_path, show_col_types = FALSE)
  valid_speakers <- speakers_df |>
    filter(!is.na(speaker_std)) |>
    mutate(speaker_key = .norm_key(speaker_std)) |>
    pull(speaker_key) |>
    unique()
} else {
  warning("⚠️ speakers.csv not found. Keeping all speakers.")
  valid_speakers <- unique(speaker_table$speaker_key)
}

# ---- filter speaker columns by speakers.csv ----
if (exists("speaker_matrix") && nrow(speaker_matrix) > 0) {
  speaker_cols_to_keep <- paste0("speaker_", valid_speakers)
  existing_speaker_cols <- grep("^speaker_", names(speaker_matrix), value = TRUE)
  keep_cols <- intersect(existing_speaker_cols, speaker_cols_to_keep)
  speaker_matrix <- speaker_matrix |>
    select(any_of(c("n", keep_cols)))
  removed_cols <- setdiff(existing_speaker_cols, keep_cols)
  message("Filtered to ", length(keep_cols), " valid speakers from speakers.csv.")
  if (length(removed_cols) > 0) {
    message("Removed ", length(removed_cols), " speakers not found in speakers.csv.")
  }
}

# ---- build transcript index ----
transcript_index <- tibble(file_abs = files) |>
  mutate(
    n    = suppressWarnings(as.integer(tools::file_path_sans_ext(path_file(file_abs)))),
    file = path_file(file_abs)
  ) |>
  select(n, file) |>
  left_join(metadata_df, by = "n") |>
  left_join(speaker_matrix, by = "n") |>
  arrange(n)

# ---- replace NA with 0 ----
speaker_cols_present <- grep("^speaker_", names(transcript_index), value = TRUE)
topic_cols_present   <- grep("^topic_", names(transcript_index), value = TRUE)

if (length(speaker_cols_present) > 0) {
  transcript_index <- transcript_index |>
    mutate(across(all_of(speaker_cols_present), ~ replace_na(., 0L)))
}
if (length(topic_cols_present) > 0) {
  transcript_index <- transcript_index |>
    mutate(across(all_of(topic_cols_present), ~ replace_na(., 0L)))
}

# ---- add summary counts ----
transcript_index <- transcript_index |>
  mutate(
    n_topics   = if (length(topic_cols_present) > 0)
      rowSums(across(all_of(topic_cols_present)), na.rm = TRUE) else NA_integer_,
    n_speakers = if (length(speaker_cols_present) > 0)
      rowSums(across(all_of(speaker_cols_present)), na.rm = TRUE) else NA_integer_
  )

# ---- reorder columns and rename n to id ----
# Descriptive columns first, then speaker/topic counts, then the speaker_*
# and topic_* boolean (1/0) indicator columns used for filtering.
.desc_cols <- intersect(
  c("n", "file", "date", "original_id", "in_book",
    "in_online_archive", "type", "summary", "speakers"),
  names(transcript_index)
)
.cnt_cols <- intersect(c("n_speakers", "n_topics"), names(transcript_index))
# speaker columns are sorted so the order does not depend on which
# transcript is scanned first; topic columns keep their authored order
.s_cols   <- sort(grep("^speaker_", names(transcript_index), value = TRUE))
.t_cols   <- grep("^topic_",   names(transcript_index), value = TRUE)

transcript_index <- transcript_index |>
  select(all_of(c(.desc_cols, .cnt_cols, .s_cols, .t_cols))) |>
  rename(id = n)

# ---- diagnostics ----
if (any(is.na(transcript_index$id))) {
  warning("Non-numeric filenames detected; some `id` values are NA.")
}
if ("date" %in% names(transcript_index) && any(is.na(transcript_index$date))) {
  message("ℹ️ Some transcripts are missing date information.")
}

message("Speaker columns kept: ", length(speaker_cols_present))
message("Topic columns created: ", length(topic_cols_present))

# ---- save output ----
dir_create("data")
save(transcript_index, file = "data/transcript_index.rda", compress = "bzip2")

message("✅ Saved transcript_index to data/transcript_index.rda (",
        nrow(transcript_index), " transcripts; ",
        length(topic_cols_present), " topic cols; ",
        length(speaker_cols_present), " speaker cols).")
