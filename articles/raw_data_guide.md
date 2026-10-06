# Raw Data Guide

## About the Vladivideos

Between 1990 and 2000, Vladimiro Montesinos Torres, the head of Peru’s
National Intelligence Service under President Alberto Fujimori, secretly
recorded meetings in which he bribed politicians, judges, military
officers, media executives, and businesspeople. Most of the aptly named
*Vladivideo* footage (and subsequent transcripts included in this
package) was covertly recorded from within Montesinos’ office,
unbeknownst to his counterparts.

Select recordings became public in 2000 and triggered the collapse of
the Fujimori government. The rest were made public in 2001 during
Congressional investigations and criminal proceedings. The Fujimori
presidency remains one of the most extensively documented cases of
systemic corruption in Latin American history, thanks to the evidence
from the *Vladivideos,* such as the one shown below from the Peruvian
Congressional Archives.

[![Vladivideo
069A.](https://img.youtube.com/vi/krW92zMwk7E/hqdefault.jpg)](https://www.youtube.com/watch?v=krW92zMwk7E)

*Vladivideo 069A: October 14, 1998. Source:
[LUM](https://lum.cultura.pe/cdi/video/reunion-de-jose-francisco-crousillat-y-vladimiro-montesinos).*

The videos capture corruption across every major institution of the
Peruvian state: legislators accepting cash to switch party allegiances,
military generals coordinating electoral suppression, judges confirming
their availability to rule in Montesinos’s favor, and even television
channel owners receiving monthly payments to censor news coverage.

See, for example, this exchange about consolidating power in the
judicial branch between Montesinos and Alipio Montes de Oca, Supreme
Court Judge (Transcript 15[^1], May 3, 1998). This exchange is printed
in English with Spanish original text in italics below.[^2]

**MONTES DE OCA —** Okay, just say it.  
***MONTES DE OCA —*** *Ya, di no más.*

**MONTESINOS TORRES —** The first is that you rejoin the Executive
Commission.  
***MONTESINOS TORRES —*** *La primera es que te reincorpores a la
Comisión Ejecutiva.*

**MONTES DE OCA —** Okay.  
***MONTES DE OCA —*** *Ya.*

**MONTESINOS TORRES —** Because on Monday I have to make a move.  
***MONTESINOS TORRES —*** *Porque el lunes tengo que dar un golpe.*

**MONTES DE OCA —** Okay.  
***MONTES DE OCA —*** *Ya.*

**MONTESINOS TORRES —** I already spoke with Víctor Raúl and with Serpa;
they agree that the (unintelligible). Someone has told them what we are
going to do on Monday. And the next step is (unintelligible) of the
National Elections Jury (unintelligible), the President of the Jury
(unintelligible).  
***MONTESINOS TORRES —*** *Ya hablé con Víctor Raúl y con Serpa, están
de acuerdo en que los (ininteligible) alguien les ha dicho lo que vamos
a hacer el lunes. Y el siguiente paso es (ininteligible) del Jurado
Nacional de Elecciones (ininteligible) el Presidente del Jurado
(ininteligible).*

**MONTES DE OCA —** Right, that is why I am asking you for
(unintelligible), and what we had agreed on, remember (unintelligible).
So we talk more directly here; we leave it that way (unintelligible).  
***MONTES DE OCA —*** *Ya, por eso yo te estoy pidiendo (ininteligible)
y que habíamos quedado te acuerdas (ininteligible). Entonces,
conversamos más directos acá, quedamos así (ininteligible).*

**bribeR** provides structured access to transcripts of 95 of these
recordings, which contain 45,337 individual speech turns. The package
also includes relevant metadata about the 139 individuals recorded
speaking and 15 topics.

This page introduces the raw data, highlighting how it is organized at
the transcript-, speaker-, and topic-level. This page uses some of the
functions included in **bribeR**, all of which are detailed in the
[**User
Guide**](https://jessietrudeau.com/bribeR/articles/using_briber.html)**.**

## Transcripts

The corpus spans recordings made between 1998 and 2000, covering the
period after Fujimori’s successful bid for a second term through the
final months before the regime’s collapse. Transcripts were collected
from two main sources:

- **LUM digital collections:** 58 transcripts accessed through the
  [digital
  holdings](https://lum.cultura.pe/cdi/busqueda/colecciones?field_coleccion=55&field_palabra_clave%5B%5D=13462&field_year=)
  of the *Lugar de la Memoria, la Tolerancia y la Inclusión Social*, an
  entity that is part of the Peruvian National Ministry of Culture.
  (LUM).
- **Congressional print volumes:** 37 additional transcripts from the
  six-volume collection [*En la sala de la corrupción: Videos y audios
  de Vladimiro Montesinos
  (1998–2000)*](https://books.google.com/books/about/En_la_sala_de_la_corrupci%C3%B3n.html?id=q7XHPgAACAAJ),
  edited by Antonio Zapata Velasco and published by the Fondo Editorial
  del Congreso del Perú. These volumes reproduce records originally made
  available by the Peruvian Congress, including the transcripts
  available through LUM as well as additional transcripts not available
  in LUM’s online database. We digitized and OCRed the transcripts that
  were present only in the print volumes.

``` r

library(bribeR)
library(dplyr)
library(ggplot2)

## There are 95 transcripts in the dataset
meta <- read_transcript_meta_data()
nrow(meta)
#> [1] 95
```

Transcripts range from brief exchanges of a few hundred words to lengthy
multi-hour meetings exceeding 29,000 words. The median transcript is
approximately 8,500 words (approximately an hour-long conversation).

``` r

summary(meta$n_words)
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#>     515    4584    8630    9086   11857   29096

ggplot(meta, aes(x = n_words)) +
  geom_histogram(bins = 25, fill = "#8B1A1A", color = "white") +
  labs(
    title = "Distribution of transcript length",
    x     = "Words per transcript",
    y     = "Count"
  ) +
  theme_minimal(base_size = 13)
```

![](raw_data_guide_files/figure-html/length-hist-1.png)

## Speakers

Users can access biographical and institutional metadata for the 139
individuals recorded speaking in the Vladivideos transcripts through the
`speakers` dataset. Each person is classified by their institutional
role at the time of the recordings.

``` r

head(speakers[, c("speaker", "position", "type", "party", "speaker_std")])
#> # A tibble: 6 × 5
#>   speaker                         position               type  party speaker_std
#>   <chr>                           <chr>                  <chr> <chr> <chr>      
#> 1 vladimiro montesinos            Chief Advisor to the … mont… NA    montesinos 
#> 2 desconocido                     Placeholder for any u… other NA    desconocido
#> 3 alexander martin kouri bumachar Congressman (1992-199… cong… PPC   alex kouri 
#> 4 representante de lucchetti      Representative of the… busi… NA    lucchetti  
#> 5 eduardo ferrero costa           Minister of Foreign A… bure… NA    eduardo fe…
#> 6 carlos ferrero costa            Constituent Congressm… cong… NM    carlos fer…
```

Speakers are grouped into thirteen categories. Vladimiro Montesinos is
in his own category:

| type | Count | Description |
|----|----|----|
| `montesinos` | 1 | Vladimiro Montesinos, Chief Advisor to the National Intelligence Service (SIN) |
| `security` | 37 | Military and police officers |
| `bureaucrat` | 20 | Civil servants |
| `congress` | 19 | Members of Congress, including allies and opposition members bribed to switch allegiance |
| `media` | 13 | Television channel and newspaper executives |
| `foreign` | 10 | Foreign citizens and officials, including diplomats |
| `siberia` | 10 | Individuals investigated or questioned during Plan Siberia searches |
| `judiciary` | 9 | Judges, prosecutors, and members of the electoral tribunals |
| `illicit` | 5 | Individuals primarily associated with armed groups |
| `elected official` | 4 | Mayors, executives, and (non-Congressional) other elected officials |
| `intermediaries` | 4 | Montesinos’ non-state intermediaries and trusted actors, including private lawyers and image advisers |
| `other` | 4 | Private individuals with no institutional role |
| `businessperson` | 3 | Private sector executives and financiers |

This figure shows that the three most common types of speakers to be
recorded are members of the security sector, bureaucrats, and
congresspeople.

``` r

speakers |>
  count(type, sort = TRUE) |>
  ggplot(aes(x = reorder(type, n), y = n)) +
  geom_col(fill = "#8B1A1A") +
  coord_flip() +
  labs(
    title = "Speakers by institutional type",
    x     = NULL,
    y     = "Number of speakers"
  ) +
  theme_minimal(base_size = 13)
```

![](raw_data_guide_files/figure-html/type-bar-1.png)

About 12% of all speech turns – 5,292 turns across 66 of the 95
transcripts – carry the speaker identifier `desconocido` (unidentified).
**This is a placeholder, not one single person.** Unidentified text that
is labeled as `desconocido` is often genuinely unknown (e.g., it is
unclear from the audio or video file who said it), or is spoken by
individuals that are unidentified, including messengers, aides, or other
staffers who quickly enter and exit, or are silent for most of the
conversation apart from salutations. In cases in the latter category,
their spoken text in the original transcripts is labeled as `El señor`
or a similar generic title with no name attached.

## Topics

Each transcript is hand-coded[^3] and classified by topic(s). The 15
topics include:

| Topic | Description |
|----|----|
| `state_capture` | Co-optation of state institutions |
| `reelection` | Fujimori’s 2000 reelection campaign |
| `media` | Bribery of television channels and newspapers |
| `promotions` | Military and police promotions in exchange for loyalty |
| `foreign` | Foreign policy and international relations |
| `ivcher` | Baruch Ivcher, a media owner stripped of Peruvian citizenship after exposing corruption in the Fujimori regime |
| `canal4` | Events surrounding Canal 4 (RBC Televisión), an opposition television network |
| `security` | Domestic public security and anti-opposition suppression |
| `wiese` | Wiese banking group, a financial partner of the regime |
| `lucchetti_factory` | Lucchetti factory zoning and construction controversy |
| `ecuador` | 1998 negotiations to settle the border dispute with Ecuador |
| `referendum` | Presidential term limits referendum |
| `municipal98` | 1998 municipal elections |
| `miraflores` | 1998 Miraflores district elections |
| `appointments` | Appointing, reassigning and removing public sector officials |

As demonstrated by [McMillan and
Zoido](https://www.aeaweb.org/articles?id=10.1257/0895330042632690)
(2004), capture of the media was the most common topic discussed in the
*Vladivideos*, followed by Fujimori’s reelection campaign in 2000 and
domestic security operations.

``` r

topic_names <- c(
  "state_capture", "reelection", "media", "promotions", "foreign",
  "ivcher", "canal4", "security", "wiese", "lucchetti_factory",
  "ecuador", "referendum", "municipal98", "miraflores", "appointments"
)

topic_counts <- sapply(topic_names, function(t) {
  length(get_transcript_id(topic = t))
})

data.frame(topic = topic_names, n = topic_counts) |>
  ggplot(aes(x = reorder(topic, n), y = n)) +
  geom_col(fill = "#8B1A1A") +
  coord_flip() +
  labs(
    title = "Transcripts per topic",
    x     = NULL,
    y     = "Number of transcripts"
  ) +
  theme_minimal(base_size = 12)
```

![](raw_data_guide_files/figure-html/topic-counts-1.png)

Many of the conversations in *Vladivideo* recordings covered more than
one topic.

``` r

meta |>
  mutate(n_topics = lengths(topics)) |>
  count(n_topics) |>
  ggplot(aes(x = factor(n_topics), y = n)) +
  geom_col(fill = "#8B1A1A") +
  labs(
    title = "Topics per transcript",
    x     = "Number of topics",
    y     = "Number of transcripts"
  ) +
  theme_minimal(base_size = 13)
```

![](raw_data_guide_files/figure-html/co-occurrence-bar-1.png)

[^1]: Originally numbered Transcript 888 in the Congress of Peru’s
    archive.

[^2]: The transcripts in the **bribeR** database are not translated from
    their original Spanish version. This is translated just as an
    example for readability in the vignette.

[^3]: Each transcript was read and validated by 2-3 native
    Spanish-language speakers and classified as pertaining to one or
    more relevant topics. These were inductively determined by a close
    reading of the transcripts. Then, their initial classification was
    validated using Claude Opus 5.5, and validated by expert coders
    again.
