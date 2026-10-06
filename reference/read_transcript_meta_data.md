# Read transcript-level metadata (id, date, speakers, duration, topics)

Builds a tidy data frame of transcript metadata from bundled package
data. Combines information from three internal sources:

1.  **transcript_index** (transcript identifiers, dates, topic flags),

2.  **speakers_per_transcript** (speaker roster per transcript), and

3.  **compiled_transcripts** (word counts derived from the `speech`
    column).

## Usage

``` r
read_transcript_meta_data(id = NULL, quiet = TRUE)
```

## Arguments

- id:

  Optional numeric vector of transcript IDs to return metadata for
  (e.g., `5`, or `c(5, 12, 47)`). If `NULL` (the default), metadata for
  every transcript is returned. IDs with no matching transcript are
  dropped with a warning naming them.

- quiet:

  Logical; if `FALSE`, prints progress messages. Default `TRUE`.

## Value

A tibble with one row per transcript and columns:

- `id` (numeric): transcript identifier.

- `date` (Date): date associated with the transcript (or `NA` if
  absent).

- `speakers` (list of character): unique, sorted vector of speakers for
  the transcript.

- `n_words` (integer): total word count across the transcript's `speech`
  column.

- `topics` (list of character): vector of topic names inferred from
  `topic_*` flags.

## Details

- **Transcript ID (`id`) and `date`:** Read from the bundled
  `transcript_index` dataset.

- **Topics (`topics` list-column):** Columns in `transcript_index` whose
  names start with `topic_` are interpreted as topic flags (1/0
  integers). Topic names are normalized by removing the `topic_` prefix
  and replacing `_` with spaces.

- **Speakers (`speakers` list-column):** Read from the bundled
  `speakers_per_transcript` dataset. Speaker columns are collapsed to a
  unique, sorted character vector per transcript.

- **Duration (`n_words`):** Computed from the bundled
  `compiled_transcripts` dataset by summing whitespace-delimited tokens
  in the `speech` column for each unique transcript `id`.

## See also

[`read_transcripts()`](https://jessietrudeau.com/bribeR/reference/read_transcripts.md),
[`get_transcript_speakers()`](https://jessietrudeau.com/bribeR/reference/get_transcript_speakers.md)

## Examples

``` r
# \donttest{
# Load metadata for all transcripts
meta <- read_transcript_meta_data()
head(meta)
#> # A tibble: 6 × 5
#>      id date       speakers  n_words topics   
#>   <dbl> <date>     <list>      <int> <list>   
#> 1     1 1998-01-08 <chr [5]>    9384 <chr [1]>
#> 2     2 1998-01-12 <chr [2]>   13035 <chr [2]>
#> 3     3 1998-01-20 <chr [3]>    4895 <chr [2]>
#> 4     4 1998-01-23 <chr [3]>   16803 <chr [3]>
#> 5     5 1998-01-28 <chr [6]>   15535 <chr [2]>
#> 6     6 1998-02-10 <chr [4]>    9583 <chr [1]>

# Metadata for a single transcript
read_transcript_meta_data(5)
#> # A tibble: 1 × 5
#>      id date       speakers  n_words topics   
#>   <dbl> <date>     <list>      <int> <list>   
#> 1     5 1998-01-28 <chr [6]>   15535 <chr [2]>

# Metadata for several transcripts
read_transcript_meta_data(c(5, 12, 47))
#> # A tibble: 3 × 5
#>      id date       speakers  n_words topics   
#>   <dbl> <date>     <list>      <int> <list>   
#> 1     5 1998-01-28 <chr [6]>   15535 <chr [2]>
#> 2    12 1998-04-14 <chr [3]>   11547 <chr [2]>
#> 3    47 1999-04-04 <chr [2]>    9759 <chr [1]>
# }
```
