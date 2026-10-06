# bribeR Data Guide

The data available in **bribeR** includes cleaned and processed versions
of the raw transcript data described in the Raw Data Guide, as well as
companion metadata files to facilitate analysis. This vignette explains
what each dataset contains and how to combine them.

## Included data

### `compiled_transcripts`

This is the main dataset, containing every spoken line from all 95
transcripts, indexed by transcript number.[^1] Each row corresponds to
one speech turn within a transcript.

``` r

library(bribeR)
library(dplyr)

transcripts <- read_transcripts()
glimpse(transcripts)
#> Rows: 45,337
#> Columns: 6
#> $ id          <dbl> 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1…
#> $ row_id      <int> 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17,…
#> $ date        <date> 1998-01-08, 1998-01-08, 1998-01-08, 1998-01-08, 1998-01-0…
#> $ speaker_std <chr> "background", "montesinos", "menendez", "montesinos", "men…
#> $ speaker     <chr> "background", "el señor montesinos torres.-", "el señor go…
#> $ speech      <chr> "Departamento de Transcripciones CONGRESO DE LA REPÚBLICA …
```

| Column        | Type      | Description                            |
|---------------|-----------|----------------------------------------|
| `id`          | numeric   | Transcript number                      |
| `row_id`      | numeric   | Row number within the transcript       |
| `date`        | date      | Recording date                         |
| `speaker_std` | character | Standardized speaker identifier        |
| `speaker`     | character | Raw speaker label from the source file |
| `speech`      | character | Speech text (Spanish)                  |

`id` and `date` are transcript-level variables, while `row_id`
corresponds to the within-conversation turn identifier, and
`speaker_std` and `speaker` correspond to the standardized and unedited
text label for the speaker, respectively. The `speech` variable is
unedited and in its original Spanish-language format.

### `transcript_index`

This wide-format file contains one row per transcript, combining
descriptive metadata with binary indicator columns that take a value of
1 if the transcript is about the topics or if the speakers are present.
This file contains all transcript-level metadata in **bribeR**. Metadata
variable descriptions are shown in the below table.

``` r

head(transcript_index[, c("id", "file", "date", "original_id", "type", "summary")])
#> # A tibble: 6 × 6
#>      id file  date       original_id type  summary                              
#>   <int> <chr> <date>     <chr>       <chr> <chr>                                
#> 1     1 1.csv 1998-01-08 864         video Montesinos meets Daniel Borobio and …
#> 2     2 2.csv 1998-01-12 1312        video The journalist Patricio Ricketts vis…
#> 3     3 3.csv 1998-01-20 896         audio Montesinos meets with businessman Ju…
#> 4     4 4.csv 1998-01-23 869         video Montesinos and Foreign Minister Edua…
#> 5     5 5.csv 1998-01-28 872         video Montesinos reviews Alexander Kouri's…
#> 6     6 6.csv 1998-02-10 858         audio Part one of a lunch between Montesin…
```

| Column | Type | Description |
|----|----|----|
| `id` | numeric | Transcript number |
| `file` | character | Source transcript filename (e.g. `"14.csv"`) |
| `date` | date | Recording date |
| `original_id` | character | Original transcript number in book or LUM archive |
| `in_book` | integer | 1 if available in print book, 0 otherwise |
| `in_online_archive` | integer | 1 if available in the LUM online archive, 0 otherwise |
| `type` | character | Recording medium (`"audio"` or `"video"`) |
| `summary` | character | Transcript summary (in English)[^2] |
| `speakers` | character | List of speaker names in the transcript |
| `n_speakers` | integer | Number of speakers in the transcript |
| `n_topics` | integer | Number of topics discussed in the transcript |
| `speaker_*` | integer | Speaker indicators (1/0) |
| `topic_*` | integer | Topic indicators (1/0) |

The 15 `topic_*` and 139 `speaker_*` columns take on a value of 1 if the
topic or speaker is present and a value of 0 otherwise. They are
designed for fast filtering for specific speakers or topics without
loading the full corpus.

``` r

# 15 topics in the corpus
names(transcript_index)[grepl("^topic_", names(transcript_index))]
#>  [1] "topic_referendum"        "topic_ecuador"          
#>  [3] "topic_lucchetti_factory" "topic_municipal98"      
#>  [5] "topic_reelection"        "topic_miraflores"       
#>  [7] "topic_canal4"            "topic_media"            
#>  [9] "topic_promotions"        "topic_ivcher"           
#> [11] "topic_foreign"           "topic_wiese"            
#> [13] "topic_appointments"      "topic_security"         
#> [15] "topic_state_capture"
```

### `speakers_per_transcript`

This file contains one row per transcript, allowing users to quickly
search for the speakers present during any one conversation. The
standardized speaker name `speaker_std` is used to indicate which
speakers are present for each conversation, sorted by chronological
speaking order. There is a minimum of 2 speakers per conversation and a
maximum of 22.

``` r

# Who was present in the first three conversations?
speakers_per_transcript |> 
  slice(1:3)
#> # A tibble: 3 × 23
#>      id speaker_std_1 speaker_std_2 speaker_std_3 speaker_std_4 speaker_std_5
#>   <dbl> <chr>         <chr>         <chr>         <chr>         <chr>        
#> 1     1 montesinos    menendez      borobio       desconocido   solis        
#> 2     2 montesinos    ricketts      NA            NA            NA           
#> 3     3 montesinos    vera abad     desconocido   NA            NA           
#> # ℹ 17 more variables: speaker_std_6 <chr>, speaker_std_7 <chr>,
#> #   speaker_std_8 <chr>, speaker_std_9 <chr>, speaker_std_10 <chr>,
#> #   speaker_std_11 <chr>, speaker_std_12 <chr>, speaker_std_13 <chr>,
#> #   speaker_std_14 <chr>, speaker_std_15 <chr>, speaker_std_16 <chr>,
#> #   speaker_std_17 <chr>, speaker_std_18 <chr>, speaker_std_19 <chr>,
#> #   speaker_std_20 <chr>, speaker_std_21 <chr>, speaker_std_22 <chr>
```

### `speakers`

This file contains biographical and institutional metadata for the 139
individuals recorded speaking in the transcripts. The variable names are
shown in the below table.

``` r

head(speakers)
#> # A tibble: 6 × 6
#>   speaker                         speaker_std     position     type  party notes
#>   <chr>                           <chr>           <chr>        <chr> <chr> <chr>
#> 1 vladimiro montesinos            montesinos      Chief Advis… mont… NA    NA   
#> 2 desconocido                     desconocido     Placeholder… other NA    NA   
#> 3 alexander martin kouri bumachar alex kouri      Congressman… cong… PPC   NA   
#> 4 representante de lucchetti      lucchetti       Representat… busi… NA    The …
#> 5 eduardo ferrero costa           eduardo ferrero Minister of… bure… NA    Brot…
#> 6 carlos ferrero costa            carlos ferrero  Constituent… cong… NM    Brot…
```

| Column | Type | Description |
|----|----|----|
| `speaker` | character | Speaker’s full name |
| `speaker_std` | character | Standardized speaker identifier |
| `position` | character | Short description of the speaker’s position |
| `type` | character | One of 13 categories described in the [Raw Data Guide](https://jessietrudeau.com/bribeR/articles/raw_data_guide.html): `montesinos`, `security`, `congress`, `judiciary`, `media`, `businessperson`, `elected official`, `bureaucrat`, `foreign`, `illicit`, `siberia`, `intermediaries` and `other`. |
| `party` | character | For elected officials, the political party at the time of the recording, given as the [V-Party](https://www.v-dem.net/) abbreviation[^3] |
| `notes` | character | Miscellaneous notes for speakers that were difficult to identify |

For example, the file contains this biographical information about some
of the speakers from Fujimori’s party:

``` r

speakers |>
  filter(type == "congress") |>
  select(speaker, speaker_std, position, type, party) |> 
  slice(3:5)
#> # A tibble: 3 × 5
#>   speaker               speaker_std position                type     party
#>   <chr>                 <chr>       <chr>                   <chr>    <chr>
#> 1 carlos blanco oropeza blanco      Congressman (1995-2000) congress NM   
#> 2 jorge trelles montero trelles     Congressman (1995-2000) congress NM   
#> 3 eduardo pando pacheco pando       Congressman (1995-2000) congress NM
```

## Linking datasets

Full-text transcript data and metadata can be linked using `id` or
`speaker_std` as a crosswalk. The table below shows which columns
connect the datasets:

| From                   | To                        | By            |
|------------------------|---------------------------|---------------|
| `compiled_transcripts` | `transcript_index`        | `id`          |
| `compiled_transcripts` | `speakers_per_transcript` | `id`          |
| `compiled_transcripts` | `speakers`                | `speaker_std` |
| `transcript_index`     | `speakers_per_transcript` | `id`          |

### `id`

The `id` column is unique to **bribeR** and assigns a unique numeric
identifier to each transcript. The original transcript numbers (e.g.,
from the the Peruvian Congress’ numbering system) are included in the
`transcript_index` metadata file, but given that many are alphanumeric
identifiers, **bribeR** generates new a new `id` variable for
simplicity.

### `speaker_std`

The `speaker_std` column resolves naming variation from the original
source material, which often varies from transcript to transcript and
can frustrate attempts at string matching (e.g. “el Señor Montesinos
Torres” and “El Señor M. Torres” both correspond to `montesinos`). It is
a standardized lowercase identifier for each speaker, consistent across
all transcripts. Use `speaker_std` rather than the raw `speaker` column
for joins and filters.

``` r

# Count Montesinos's speaking turns across all transcripts
transcripts |>
  filter(speaker_std == "montesinos") |>
  summarise(n_turns = n())
#> # A tibble: 1 × 1
#>   n_turns
#>     <int>
#> 1   16561
```

## Accessing data directly

All datasets are lazily loaded when the package is attached, so you can
reference them by name after
[`library(bribeR)`](https://jessietrudeau.com/bribeR):

``` r

nrow(compiled_transcripts)
#> [1] 45337
names(speakers)
#> [1] "speaker"     "speaker_std" "position"    "type"        "party"      
#> [6] "notes"
```

[^1]: We generate a new number within the bribeR package, see the
    [id](https://jessietrudeau.com/bribeR/articles/briber_data_guide.html#id)
    subsection for more information.

[^2]: These summaries were written by a native Spanish-language
    undergraduate RA, edited by Claude Opus 5.5, and then manually read
    and edited by the PI.

[^3]: The party codes match `v2pashname`, the party abbreviation
    variable for Peru in the V-Party dataset: `NM`, `PAP`, `RN`, `PP`,
    `PPC`, `FIM` or `AP`.
