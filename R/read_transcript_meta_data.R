#' Read transcript-level metadata (id, date, speakers, duration, topics)
#'
#' @description
#' Builds a tidy data frame of transcript metadata from bundled package data.
#' Combines information from three internal sources:
#' 1. **transcript_index** (transcript identifiers, dates, topic flags),
#' 2. **speakers_per_transcript** (speaker roster per transcript), and
#' 3. **compiled_transcripts** (word counts derived from the `speech` column).
#'
#' @details
#' - **Transcript ID (`id`) and `date`:** Read from the bundled `transcript_index` dataset.
#' - **Topics (`topics` list-column):** Columns in `transcript_index` whose names start
#'   with `topic_` are interpreted as topic flags (1/0 integers). Topic names are
#'   normalized by removing the `topic_` prefix and replacing `_` with spaces.
#' - **Speakers (`speakers` list-column):** Read from the bundled `speakers_per_transcript`
#'   dataset. Speaker columns are collapsed to a unique, sorted character vector per transcript.
#' - **Duration (`n_words`):** Computed from the bundled `compiled_transcripts` dataset by
#'   summing whitespace-delimited tokens in the `speech` column for each unique transcript `id`.
#'
#' @param id Optional numeric vector of transcript IDs to return metadata for
#'   (e.g., `5`, or `c(5, 12, 47)`). If `NULL` (the default), metadata for every
#'   transcript is returned. IDs with no matching transcript are dropped with a
#'   warning naming them.
#' @param quiet Logical; if `FALSE`, prints progress messages. Default `TRUE`.
#'
#' @return
#' A tibble with one row per transcript and columns:
#' - `id` (numeric): transcript identifier.
#' - `date` (Date): date associated with the transcript (or `NA` if absent).
#' - `speakers` (list of character): unique, sorted vector of speakers for the transcript.
#' - `n_words` (integer): total word count across the transcript's `speech` column.
#' - `topics` (list of character): vector of topic names inferred from `topic_*` flags.
#'
#' @examples
#' \donttest{
#' # Load metadata for all transcripts
#' meta <- read_transcript_meta_data()
#' head(meta)
#'
#' # Metadata for a single transcript
#' read_transcript_meta_data(5)
#'
#' # Metadata for several transcripts
#' read_transcript_meta_data(c(5, 12, 47))
#' }
#'
#' @seealso [read_transcripts()], [get_transcript_speakers()]
#' @export
read_transcript_meta_data <- function(id = NULL, quiet = TRUE) {

  # --- helper: detect truthy topic flags
  # Guards on length: when `id` matches no transcripts, dplyr evaluates the
  # rowwise topic expression below on a zero-row slice, and the flag columns
  # arrive empty rather than as a single value.
  .is_topic_marked <- function(x) {
    if (length(x) != 1) return(FALSE)
    if (is.logical(x)) return(isTRUE(x))
    if (is.numeric(x)) return(isTRUE(!is.na(x) && x != 0))
    if (is.character(x)) {
      v <- tolower(trimws(x))
      return(isTRUE(!is.na(v) && nzchar(v) && !v %in% c("0", "false", "no", "na", "n/a")))
    }
    FALSE
  }

  # --- load bundled data
  .load_pkg_data <- function(dataset_name, object_name = dataset_name) {
    env <- new.env(parent = emptyenv())
    utils::data(list = dataset_name, package = "bribeR", envir = env)
    env[[object_name]]
  }

  desc        <- .load_pkg_data("transcript_index")
  spt         <- .load_pkg_data("speakers_per_transcript")
  transcripts <- .load_pkg_data("compiled_transcripts")

  # --- check the bundled data carries the columns this function needs
  if (!"id" %in% names(desc)) stop("`transcript_index` must include column 'id'.", call. = FALSE)
  if (!"date" %in% names(desc)) {
    if (!quiet) warning("`transcript_index` has no 'date' column; setting NA for dates.")
    desc$date <- as.Date(NA)
  }
  if (!"id" %in% names(spt)) stop("`speakers_per_transcript` must include column 'id'.", call. = FALSE)

  # --- hold ids as text, so the joins below match whatever type came in
  desc <- dplyr::mutate(desc, id = as.character(.data$id))
  spt  <- dplyr::mutate(spt,  id = as.character(.data$id))

  # --- keep only the transcripts the corpus has speech turns for
  valid_ids <- unique(as.character(transcripts$id))
  desc <- dplyr::filter(desc, .data$id %in% valid_ids)

  # --- optionally restrict to the transcript IDs the caller asked for.
  # Done before the speaker pivot and word count below so that requesting a
  # single transcript does not summarise the whole corpus.
  if (!is.null(id)) {
    requested <- suppressWarnings(as.numeric(id))
    if (anyNA(requested)) {
      stop(
        "`id` must be numeric transcript IDs; could not interpret: ",
        paste(unique(as.character(id)[is.na(requested)]), collapse = ", "), ".",
        call. = FALSE
      )
    }
    requested <- unique(requested)

    # Warn about IDs with no transcript, then keep the ones that do exist.
    missing_ids <- setdiff(requested, suppressWarnings(as.numeric(desc$id)))
    if (length(missing_ids) > 0) {
      warning(
        "Transcript ID(s) not found: ",
        paste(sort(missing_ids), collapse = ", "),
        call. = FALSE
      )
    }

    desc        <- dplyr::filter(desc,        as.numeric(.data$id) %in% requested)
    spt         <- dplyr::filter(spt,         as.numeric(.data$id) %in% requested)
    transcripts <- dplyr::filter(transcripts, as.numeric(.data$id) %in% requested)
  }

  # --- collapse the wide speaker_std_1..N columns into one list-column per transcript
  spt_speaker_cols <- grep("^speaker_std_[0-9]+$", names(spt), value = TRUE)
  if (!length(spt_speaker_cols)) {
    stop("`speakers_per_transcript` must include columns like 'speaker_std_1'.", call. = FALSE)
  }

  speakers_long <- spt |>
    tidyr::pivot_longer(
      cols = dplyr::all_of(spt_speaker_cols),
      names_to = "slot",
      values_to = "speaker_std"
    ) |>
    dplyr::mutate(speaker_std = stringr::str_trim(as.character(.data$speaker_std))) |>
    dplyr::filter(!is.na(.data$speaker_std) & .data$speaker_std != "") |>
    dplyr::distinct(.data$id, .data$speaker_std)

  speakers_vec <- speakers_long |>
    dplyr::group_by(.data$id) |>
    dplyr::summarise(speakers = list(sort(unique(.data$speaker_std))), .groups = "drop")

  # --- topics: from the topic_* flag columns of transcript_index
  topic_cols <- grep("^topic_", names(desc), value = TRUE)
  topics_vec <- if (length(topic_cols)) {
    desc |>
      dplyr::rowwise() |>
      dplyr::mutate(
        topics = list({
          chosen <- character(0)
          for (tc in topic_cols) {
            if (.is_topic_marked(get(tc))) {
              nm <- gsub("^topic_", "", tc)
              nm <- gsub("_", " ", nm)
              chosen <- c(chosen, nm)
            }
          }
          unique(chosen)
        })
      ) |>
      dplyr::ungroup() |>
      dplyr::select("id", "topics")
  } else {
    dplyr::transmute(desc, id = .data$id, topics = list(character(0)))
  }

  # --- word counts: from compiled_transcripts speech column
  transcripts <- dplyr::mutate(transcripts, id = as.character(.data$id))

  duration_df <- transcripts |>
    dplyr::filter(!is.na(.data$speech) & .data$speech != "") |>
    dplyr::group_by(.data$id) |>
    dplyr::summarise(
      n_words = as.integer(sum(stringr::str_count(.data$speech, "\\S+"), na.rm = TRUE)),
      .groups = "drop"
    )

  # --- convert joining tables to numeric id before assembly
  speakers_vec <- dplyr::mutate(speakers_vec, id = as.numeric(.data$id))
  duration_df  <- dplyr::mutate(duration_df,  id = as.numeric(.data$id))
  topics_vec   <- dplyr::mutate(topics_vec,   id = as.numeric(.data$id))

  # --- assemble output
  meta <- desc |>
    dplyr::transmute(id = as.numeric(.data$id), date = .data$date) |>
    dplyr::left_join(speakers_vec, by = "id") |>
    dplyr::left_join(duration_df,  by = "id") |>
    dplyr::left_join(topics_vec,   by = "id")

  # a transcript with no speakers, topics or words gets nothing from the joins
  # above, so create those columns when they are absent
  if (!"speakers" %in% names(meta)) meta$speakers <- replicate(nrow(meta), character(0), simplify = FALSE)
  if (!"topics"   %in% names(meta)) meta$topics   <- replicate(nrow(meta), character(0), simplify = FALSE)
  if (!"n_words"  %in% names(meta)) meta$n_words  <- NA_integer_

  meta <- meta |>
    dplyr::select("id", "date", "speakers", "n_words", "topics") |>
    tibble::as_tibble()

  if (!quiet) {
    message("Built metadata for ", nrow(meta), " transcripts.")
  }

  meta
}










