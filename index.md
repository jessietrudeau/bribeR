# bribeR

**bribeR** is an R package for accessing and analyzing text transcript
data from the *Vladivideos,* covert recordings documenting bribery and
corruption during Alberto Fujimori’s presidency in Peru (1990-2000).

This package provides user-friendly access to a large digital archive of
*Vladivideo* transcripts and metadata, including data about 139
individuals named in the files and 15 expert-coded topics of importance
during the Fujimori presidency.

![Network of speakers recorded in the Vladivideo files, with Montesinos
at the center](reference/figures/network_viz.png)

Speakers and topics recorded in the *Vladivideo* files, with Montesinos
in the center. See [Network
Visualization](https://jessietrudeau.com/bribeR/articles/transcript_network_app.html)
for more details.

------------------------------------------------------------------------

## Installation

To install the package in your console, run one of the two below
commands:

``` r

# Install from CRAN
install.packages("bribeR")

# Or install the development version from GitHub
# install.packages("remotes")
remotes::install_github("jessietrudeau/bribeR")
```

------------------------------------------------------------------------

## Core Functions

This package provides three families of functions to access, organize,
and analyze *Vladivideo* data. For a full online guide, see the [bribeR
User
Guide](https://jessietrudeau.com/bribeR/articles/using_briber.html).

**1. Read transcripts**

These functions load transcript data as tibbles or load original source
.csv files.

**2. Find transcripts**

These functions allow the user to filter transcripts by specific
speakers, topics, or transcript ID numbers.

**3. Integrate with transcript metadata**

These functions allow the user to integrate transcript-level metadata
with full-text transcripts or information about speakers.

------------------------------------------------------------------------

## Basic Usage

The syntax of `bribeR` is designed to help users easily find and
download transcripts relevant to their interest. For example, a user
interested in obtaining transcript text data and metadata about all
conversations involving **media manipulation** would run the following
lines of code:

``` r

# Load data 
library(bribeR)

# Find specific transcripts about media manipulation
media_ids <- get_transcript_id(topic = "media")

# Get the metadata summary of the transcripts about media manipulation
meta <- read_transcript_meta_data(media_ids)

# Load full-text transcripts about media manipulation
media_transcripts <- read_transcripts(media_ids)
```

------------------------------------------------------------------------

## Datasets

bribeR includes four searchable datasets:

| Dataset | Description |
|----|----|
| `compiled_transcripts` | Full text corpus: 45,337 speech turns across 95 transcripts |
| `transcript_index` | Wide-format transcript-level metadata, including dates, recording format, summaries, topics, and speakers present |
| `speakers_per_transcript` | Speaker roster per transcript |
| `speakers` | Speaker-level metadata |

A full description of the raw data is in the [Raw Data
Guide](https://jessietrudeau.com/bribeR/articles/raw_data_guide.html),
as well as a description of additional speaker- and topic-level metadata
accessible in **bribeR.** A full description of the datasets included in
the package is in the [bribeR Data
Guide](https://jessietrudeau.com/bribeR/articles/briber_data_guide.html).

------------------------------------------------------------------------

## Contributing

Contributions are welcome. Please create a new branch for a feature, to
open an issue, or for a pull request on
[GitHub](https://github.com/jessietrudeau/bribeR/issues).

Document exported functions with roxygen2 comments. Add or update tests
in tests/testthat/.

------------------------------------------------------------------------

## Credits

All *Vladivideo* transcript data included in this package are drawn from
publicly available materials, including print volumes edited by Antonio
Zapata Velasco and published by the Fondo Editorial del Congreso del
Perú, and online Congressional archives from
[LUM/CDI](https://lum.cultura.pe/cdi/busqueda/colecciones?field_coleccion=55&field_palabra_clave%5B%5D=13462&field_year=)
(*Lugar de la Memoria, la Tolerancia y la Inclusión Social*), the
Ministry of Culture’s Place of Memory, Tolerance, and Social Inclusion.
In accordance with LUM’s guidance, we understand these official
documentary materials to fall outside copyright protection under Article
9(b) of Peru’s [Legislative Decree
No. 822](https://www.leyes.congreso.gob.pe/Documentos/DecretosLegislativos/00822.pdf),
which excludes official legislative, administrative, and judicial texts,
since the original entity that provided the *Vladivideo* data was the
Congress of the Republic of Peru.

This research was generously supported by Syracuse University’s [Open
Source Program Office](https://opensource.syracuse.edu/) (OSPO) and the
Sloan Foundation (#G-2023-20946, \#G-2025-79206).

## Citation

If you use **bribeR** in your research, please cite it as:

> Trudeau, Jessie, and Soto Plaza, Andrés. 2026. *bribeR: Tools for
> Analyzing Vladivideo Transcript Data*. R package version 0.1.0.
> <https://github.com/jessietrudeau/bribeR>
