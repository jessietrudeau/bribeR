# Standalone copy of bribeR::run_transcript_network_app(), for shinylive
# export. It is self-contained -- its own data copies, written by
# prepare_data.R, and no library(bribeR) -- because shinylive/webR can only
# install packages from a wasm repository, and bribeR is not published to one.
#
# This file and R/run_transcript_network_app.R must behave identically. A
# change to either one has to be made in both.

library(shiny)
library(dplyr)
library(tidyr)
library(stringr)
library(tidyselect)
library(visNetwork)
library(fs)
library(purrr)
library(tibble)
library(readr)

# ---- 0) Load bundled data --------------------------------------------------
transcript_index   <- readRDS("transcript_index.rds")
speakers_df        <- readRDS("speakers_per_transcript.rds")
topic_descriptions <- readRDS("topic_descriptions.rds")
speaker_info_raw   <- readRDS("speakers.rds")

# ---- 1) Resolve transcript directory ---------------------------------------
transcript_dir <- "transcripts"

# ---- 2) Optional Montesinos image ------------------------------------------
# Files under www/ are served by Shiny at the app root automatically.
has_img <- file.exists(file.path("www", "montesinos.PNG"))
montesinos_image <- if (has_img) "montesinos.PNG" else NULL

# ---- Tooltip style for visInteraction --------------------------------------
tooltip_style <- paste0(
  "position: fixed;",
  "visibility: hidden;",
  "padding: 10px 14px;",
  "font-family: sans-serif;",
  "font-size: 14px;",
  "line-height: 1.5;",
  "color: #000;",
  "background-color: #f5f4ed;",
  "border: 1px solid #d5d4c7;",
  "border-radius: 4px;",
  "box-shadow: 3px 3px 10px rgba(0,0,0,0.15);",
  "max-width: 450px;",
  "white-space: normal;",
  "word-wrap: break-word;",
  "overflow-wrap: break-word;",
  "word-break: normal;",
  "pointer-events: none;",
  "z-index: 9999;"
)

# ---- 3) Build UI ------------------------------------------------------------
ui <- fluidPage(
  titlePanel("Transcript-Topic-Speaker Network"),
  tabsetPanel(
    tabPanel(
      "Speaker-Topic Network",
      fluidRow(
        column(
          width = 12,
          visNetworkOutput("speaker_topic_network", height = "700px")
        )
      ),
    ),
    tabPanel(
      "Speaker Co-Appearance Network",
      visNetworkOutput("speaker_co_network", height = "700px")
    )
  ),
  fluidRow(
    column(width = 12, br(), uiOutput("type_legend"))
  )
)

# ---- 4) Server ---------------------------------------------------------------
server <- function(input, output, session) {

  # How many transcripts each speaker appears in, counted from the transcript
  # files. Empty when no transcript directory is available.
  speaker_frequency <- {
    if (!is.null(transcript_dir) && nzchar(transcript_dir) && dir.exists(transcript_dir)) {
      files <- dir_ls(transcript_dir, regexp = "\\.(csv|tsv)$", recurse = TRUE)
      sf <- map_dfr(files, function(path) {
        ext <- tools::file_ext(path)
        df <- if (identical(ext, "csv")) {
          read_csv(path, col_types = cols())
        } else if (identical(ext, "tsv")) {
          read_tsv(path, col_types = cols())
        } else {
          tibble()
        }
        if (!("speaker_std" %in% names(df))) {
          return(tibble(speaker_std = character(), file = character()))
        }
        df |>
          filter(!is.na(.data$speaker_std), .data$speaker_std != "") |>
          distinct(.data$speaker_std) |>
          mutate(file = basename(path))
      })
      sf |>
        distinct(.data$speaker_std, .data$file) |>
        count(.data$speaker_std, name = "conversation_count")
    } else {
      tibble(speaker_std = character(), conversation_count = integer())
    }
  }

  # === Type colors ===
  type_colors <- c(
    "montesinos"       = "#E63946",
    "congress"         = "#BDB2FF", "security"   = "#A0C4FF", "bureaucrat" = "#CAFFBF",
    "judiciary"        = "#FDFFB6", "foreign"    = "#FFD6A5", "media"      = "#FFADAD",
    "illicit"          = "#FFC6FF", "elected official" = "#9BF6FF",
    "businessperson"   = "#4daf4a", "siberia"    = "#B5838D",
    "intermediaries"   = "#E9C46A", "other"      = "#D9D9D9"
  )

  # === Topic reshape ===
  long_topics <- transcript_index |>
    select("id", starts_with("topic_")) |>
    pivot_longer(
      starts_with("topic_"),
      names_to = "topic",
      values_to = "included"
    ) |>
    filter(.data$included == 1L) |>
    mutate(
      id    = as.character(.data$id),
      topic = str_remove(.data$topic, "^topic_")
    )

  # === Speakers reshape ===
  speaker_long <- speakers_df |>
    pivot_longer(
      cols = -"id",
      names_to = "speaker_col",
      values_to = "speaker"
    ) |>
    # desconocido is a placeholder for any unidentified speaker rather than
    # one person, so it is left out of the network
    filter(!is.na(.data$speaker), .data$speaker != "",
           .data$speaker != "desconocido") |>
    mutate(
      id      = as.character(.data$id),
      speaker = str_trim(.data$speaker)
    )

  # === Edges: Speaker -> Topic ===
  edges_speaker_topic <- speaker_long |>
    # one row per speaker-topic pair: a transcript has many of each
    inner_join(long_topics, by = "id", relationship = "many-to-many") |>
    mutate(speaker_std = .data$speaker) |>
    distinct(.data$speaker_std, .data$topic) |>
    left_join(
      speaker_frequency |>
        mutate(speaker_std = str_to_lower(.data$speaker_std)),
      by = "speaker_std"
    ) |>
    transmute(
      from  = .data$speaker_std,
      to    = .data$topic,
      width = pmax(1, log1p(coalesce(.data$conversation_count, 0)))
    )

  # === Speaker pairs for placeholder edges (for layout support) ===
  speaker_pairs_topic_net <- speaker_long |>
    select("id", "speaker") |>
    distinct() |>
    group_by(.data$id) |>
    filter(n() > 1) |>
    summarise(
      pairs = list(combn(.data$speaker, 2, simplify = FALSE)),
      .groups = "drop"
    ) |>
    unnest("pairs") |>
    mutate(
      from = map_chr(.data$pairs, 1),
      to   = map_chr(.data$pairs, 2)
    ) |>
    select("from", "to") |>
    filter(.data$from != .data$to)

  edges_placeholder <- speaker_pairs_topic_net |>
    mutate(
      edge_id = paste(
        pmin(.data$from, .data$to),
        pmax(.data$from, .data$to),
        sep = "~~"
      )
    ) |>
    distinct(.data$edge_id, .keep_all = TRUE) |>
    select(-"edge_id") |>
    group_by(.data$from, .data$to) |>
    summarise(weight = n(), .groups = "drop") |>
    mutate(
      color = "#bbbbbb",
      width = pmax(1, log1p(.data$weight) / 2)
    )

  # === Speaker pairs for co-appearance network ===
  speaker_pairs <- speaker_long |>
    select("id", "speaker") |>
    distinct() |>
    group_by(.data$id) |>
    filter(n() > 1) |>
    summarise(
      pairs = list(combn(.data$speaker, 2, simplify = FALSE)),
      .groups = "drop"
    ) |>
    unnest("pairs") |>
    mutate(
      from = map_chr(.data$pairs, 1),
      to   = map_chr(.data$pairs, 2)
    ) |>
    select("from", "to") |>
    filter(.data$from != .data$to)

  edges_speaker_co <- speaker_pairs |>
    mutate(
      edge_id = paste(
        pmin(.data$from, .data$to),
        pmax(.data$from, .data$to),
        sep = "~~"
      )
    ) |>
    distinct(.data$edge_id, .keep_all = TRUE) |>
    select(-"edge_id") |>
    group_by(.data$from, .data$to) |>
    summarise(weight = n(), .groups = "drop") |>
    mutate(width = pmax(1, log1p(.data$weight)))

  # === Speaker nodes, from the roster plus the transcript counts ===
  nodes_speaker_base <- speaker_long |>
    transmute(id = str_trim(.data$speaker)) |>
    distinct()

  speaker_info <- speaker_info_raw |>
    mutate(
      type = str_trim(.data$type),
      # a speaker with no recorded type is shown as "other"
      type = if_else(is.na(.data$type) | .data$type == "", "other", .data$type),
      name = coalesce(.data$speaker, .data$speaker_std)
    )

  nodes_speaker_st <- nodes_speaker_base |>
    left_join(
      speaker_info |>
        mutate(
          speaker_std = str_trim(.data$speaker_std),
          position    = coalesce(.data$position, "No info"),
          type        = if_else(
            is.na(.data$type) | .data$type == "",
            "other",
            .data$type
          )
        ),
      by = join_by(id == speaker_std)
    ) |>
    left_join(
      speaker_frequency |>
        mutate(speaker_std = str_to_lower(.data$speaker_std)),
      by = join_by(id == speaker_std)
    ) |>
    mutate(
      group = "Speaker",
      color = type_colors[.data$type],
      color = ifelse(is.na(.data$color), type_colors[["other"]], .data$color),
      # Use display name as label so nodesIdSelection dropdown shows it via
      # useLabels = TRUE. On-graph text is suppressed via font.size = 0.
      label = coalesce(
        na_if(str_trim(.data$name), ""),
        .data$id
      ),
      font.size = 0,
      value = pmax(1, log1p(coalesce(.data$conversation_count, 0))),
      title = paste0(
        "<b>", coalesce(.data$name, .data$id), "</b><br>",
        "<b>Standardized ID:</b> ", .data$id, "<br>",
        "<b>Type:</b> ", coalesce(.data$type, "other"), "<br>",
        "<b>Position:</b> ", coalesce(.data$position, "No info"), "<br>",
        "<b>Transcripts:</b> ", coalesce(as.character(.data$conversation_count), "0")
      )
    ) |>
    select(
      "id", "group", "title", "color",
      "label", "font.size", "value", "name"
    ) |>
    distinct(.data$id, .keep_all = TRUE)

  # === Build speaker dropdown map: node id -> display name ================
  # useLabels = TRUE in nodesIdSelection reads the node `label` column, which
  # holds the display name. `values` restricts the dropdown to speakers, so
  # that topic nodes are left out of it. The dropdown lists speakers in the
  # order of `values`, which is alphabetical by display name.
  speaker_dropdown_values <- nodes_speaker_st$id[str_order(nodes_speaker_st$label)]

  # Drop helper `name` column before passing nodes to visNetwork
  nodes_speaker_st <- nodes_speaker_st |>
    select(-"name")

  # Add Montesinos image properties
  if (!has_img) {
    nodes_speaker_st <- nodes_speaker_st |>
      mutate(
        shape       = "dot",
        image       = NA_character_,
        size        = NA_real_,
        borderWidth = NA_real_
      )
  } else {
    nodes_speaker_st <- nodes_speaker_st |>
      mutate(
        shape       = if_else(.data$id == "montesinos", "circularImage", "dot"),
        image       = if_else(.data$id == "montesinos", montesinos_image, NA_character_),
        size        = if_else(.data$id == "montesinos", 60, NA_real_),
        borderWidth = if_else(.data$id == "montesinos", 0, NA_real_)
      )
  }

  # === Topic nodes ===
  nodes_topic_st <- long_topics |>
    transmute(id = .data$topic) |>
    distinct() |>
    left_join(
      topic_descriptions |>
        rename(topic = "topics", description = "descriptions") |>
        mutate(topic = str_remove(.data$topic, "^topic_")),
      by = join_by(id == topic)
    ) |>
    mutate(
      group = "Topic",
      label = "",
      font.size = 0,
      title = paste0(
        "<b>",
        str_to_title(str_replace_all(.data$id, "_", " ")),
        "</b><br>",
        .data$description
      ),
      value = 300,
      color = "maroon"
    ) |>
    select("id", "group", "title", "value",
           "color", "label", "font.size") |>
    distinct(.data$id, .keep_all = TRUE)

  # === Combined nodes for Speaker-Topic view ===
  nodes_st <- bind_rows(
    nodes_speaker_st |>
      select(
        "id", "group", "title", "color",
        "label", "font.size", "value", "shape",
        "image", "size", "borderWidth"
      ),
    nodes_topic_st |>
      mutate(shape = "dot") |>
      select(
        "id", "group", "title", "color",
        "label", "font.size", "value", "shape"
      )
  ) |>
    distinct(.data$id, .keep_all = TRUE)

  # === Speaker-Topic Network ===
  output$speaker_topic_network <- renderVisNetwork({
    visNetwork(
      nodes_st,
      bind_rows(
        edges_speaker_topic |>
          mutate(color = NA_character_),
        edges_placeholder
      )
    ) |>
      visNodes(
        shape = "dot",
        shapeProperties = list(
          useImageSize = FALSE,
          useBorderWithImage = TRUE
        )
      ) |>
      visEdges(
        arrows = "none",
        color = list(color = "grey")
      ) |>
      visOptions(
        highlightNearest = TRUE,
        nodesIdSelection = list(
          enabled   = TRUE,
          values    = speaker_dropdown_values,
          useLabels = TRUE,
          style     = "width: 250px;",
          main      = "Select a speaker"
        )
      ) |>
      visInteraction(
        tooltipStyle = tooltip_style
      ) |>
      visPhysics(
        solver = "forceAtlas2Based",
        stabilization = TRUE
      ) |>
      visLayout(randomSeed = 42) |>
      visEvents(
        stabilizationIterationsDone =
          "function () { this.setOptions({ physics: false }); }"
      )
  })

  # === Speaker Co-Appearance Network ===
  output$speaker_co_network <- renderVisNetwork({
    visNetwork(
      nodes_speaker_st |>
        select(
          "id", "group", "title", "color",
          "label", "font.size", "value", "shape",
          "image", "size", "borderWidth"
        ),
      edges_speaker_co
    ) |>
      visNodes(
        shape = "dot",
        shapeProperties = list(
          useImageSize = FALSE,
          useBorderWithImage = TRUE
        )
      ) |>
      visEdges(
        arrows = "none",
        color = list(color = "black")
      ) |>
      visOptions(
        highlightNearest = TRUE,
        nodesIdSelection = list(
          enabled   = TRUE,
          values    = speaker_dropdown_values,
          useLabels = TRUE,
          style     = "width: 250px;",
          main      = "Select a speaker"
        )
      ) |>
      visInteraction(
        tooltipStyle = tooltip_style
      ) |>
      visPhysics(
        solver = "forceAtlas2Based",
        stabilization = TRUE
      ) |>
      visLayout(randomSeed = 42) |>
      visEvents(
        stabilizationIterationsDone =
          "function () { this.setOptions({ physics: false }); }"
      )
  })

  # === Legend ===
  output$type_legend <- renderUI({
    all_colors <- c(type_colors, "Topics" = "maroon")
    legend_items <- map2_chr(
      names(all_colors),
      all_colors,
      function(type, color) {
        paste0(
          "<div style='display: inline-block; margin-right: 15px;
                      margin-bottom: 4px; vertical-align: middle;'>
             <span style='display: inline-block; width: 14px; height: 14px;
                          background-color:", color, ";
                          border: 1px solid #333;
                          border-radius: 50%;
                          margin-right: 6px;'></span>",
          "<span style='font-size: 14px;'>",
          str_to_title(type), "</span></div>"
        )
      }
    )
    HTML(
      paste(
        "<b>Speaker Types and Topics</b><br><div style='margin-top: 5px;'>",
        paste(legend_items, collapse = ""),
        "</div>"
      )
    )
  })
}

shinyApp(ui = ui, server = server)
