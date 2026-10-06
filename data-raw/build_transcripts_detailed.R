# data-raw/build_transcripts_detailed.R
#
# Reads every transcript CSV and stacks them into `compiled_transcripts`,
# one row per speech turn, with the recording date joined from
# Descriptions.csv. Run this before the other two build scripts.

# ---- setup ----
required_pkgs <- c("dplyr", "readr", "stringr", "purrr", "stringi")
to_install <- setdiff(required_pkgs, rownames(installed.packages()))
if (length(to_install)) install.packages(to_install, repos = "https://cloud.r-project.org")

library(dplyr)
library(readr)
library(stringr)
library(purrr)

# ---- define paths ----
transcript_dir <- "inst/data-raw/transcripts"
descriptions_path <- "data-raw/Inventory & Descriptions/Descriptions.csv"
output_path <- "data/compiled_transcripts.rda"

# ---- read descriptions ----
descriptions <- read_csv(descriptions_path, show_col_types = FALSE) |>
  select(id = n, date)

# ---- read transcripts ----
transcript_files <- list.files(transcript_dir, pattern = "\\.csv$", full.names = TRUE)

read_single_transcript <- function(file_path) {
  data <- read_csv(file_path, show_col_types = FALSE)
  n_value <- as.numeric(str_remove(basename(file_path), "\\.csv$"))

  data |>
    mutate(
      id = n_value,
      row_id = row_number()
    )
}

all_transcripts <- map_dfr(transcript_files, read_single_transcript)

# ---- attach the recording date ----
# Descriptions.csv writes dates as m/d/Y; they are parsed here so the column is
# a Date, matching transcript_index.
compiled_transcripts <- all_transcripts |>
  left_join(descriptions, by = "id") |>
  mutate(date = as.Date(date, format = "%m/%d/%Y"))

if (any(is.na(compiled_transcripts$date))) {
  stop(sprintf("%d rows have a date that is not in m/d/Y form.",
               sum(is.na(compiled_transcripts$date))))
}

# ---- lowercase speaker columns ----
# speaker_std is additionally stripped of diacritics, so that one person has a
# single identifier across transcripts. `speaker` keeps the accents as written
# in the source transcript.
compiled_transcripts <- compiled_transcripts |>
  mutate(
    across(any_of(c("speaker", "speaker_std")), tolower),
    speaker_std = stringi::stri_trans_general(speaker_std, "Latin-ASCII")
  )

# ---- order columns ----
# speaker_std sits before the speech text, as briber_data_guide describes.
compiled_transcripts <- compiled_transcripts |>
  select(id, row_id, date, speaker_std, speaker, speech)

# ---- save as RDA ----
if (!dir.exists("data")) dir.create("data")
save(compiled_transcripts, file = output_path)

message("✅ Compiled RDA saved at: ", output_path)

















