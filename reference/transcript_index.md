# Transcript Index

A wide-format lookup table with one row per transcript, combining
descriptive metadata with binary indicator columns for topics and
speakers, enabling fast filtering without loading the full corpus. It is
the single source of transcript-level metadata for the package.

## Usage

``` r
transcript_index
```

## Format

A tibble with 95 rows. Descriptive columns first, followed by the
`n_speakers` and `n_topics` summary counts, followed by the boolean
(1/0) `speaker_*` and `topic_*` indicator columns. The counts are
deliberately named with an `n_` prefix so that they are not picked up by
code selecting indicator columns with `speaker_` or `topic_`:

- id:

  Numeric transcript identifier (bribeR internal numbering).

- file:

  Source transcript filename, e.g. `"14.csv"`.

- date:

  Date of the recording.

- original_id:

  Original transcript identifier from the source archive.

- in_book:

  1 if available in print book, 0 otherwise.

- in_online_archive:

  1 if available in the online archive, 0 otherwise.

- type:

  Recording medium (`"audio"` or `"video"`).

- summary:

  Plain-language English summary of the transcript content.

- speakers:

  Free-text description of participants.

- n_speakers:

  Total number of distinct speakers in the transcript.

- n_topics:

  Total number of topics flagged for the transcript.

- speaker_SURNAME:

  Integer indicator (1/0) for each standardized speaker. One column per
  unique speaker, named `speaker_` followed by the speaker's
  standardized surname.

- topic_referendum, topic_ecuador, topic_lucchetti_factory,
  topic_municipal98, topic_reelection, topic_miraflores, topic_canal4,
  topic_media, topic_promotions, topic_ivcher, topic_foreign,
  topic_wiese, topic_appointments, topic_security, topic_state_capture:

  Integer indicator (1/0) for each topic.

## Source

Derived from the Vladivideos transcripts and accompanying metadata.
