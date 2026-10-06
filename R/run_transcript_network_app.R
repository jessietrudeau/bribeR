#' Run the Transcript-Topic-Speaker Shiny app
#'
#' Launch an interactive Shiny application that visualizes the relationships
#' between speakers and topics in a transcript collection. All data is loaded
#' from the bundled package datasets and the `data-raw/transcripts` folder.
#'
#' The app provides two network views:
#' \itemize{
#'   \item **Speaker-Topic Network**: connects speakers to the topics discussed
#'     in their transcripts.
#'   \item **Speaker Co-Appearance Network**: connects speakers who appear in the
#'     same transcript.
#' }
#'
#' @param transcript_dir Optional path to a directory of transcript CSV/TSV files
#'   (with a \code{speaker_std} column). If \code{NULL}, the app will use
#'   \code{data-raw/transcripts} from the bribeR package.
#'
#' @return A \code{shiny.appobj} that, when printed, launches the
#'   Transcript-Topic-Speaker Shiny application.
#'
#' @examples
#' \dontrun{
#' # Run the network app
#' run_transcript_network_app()
#' }
#'
#' @seealso [read_transcripts()], [read_transcript_meta_data()]
#' @export
run_transcript_network_app <- function(transcript_dir = NULL) {

  # ---- 0) Load bundled data -------------------------------------------------
  .load_pkg_data <- function(dataset_name, object_name = dataset_name) {
    env <- new.env(parent = emptyenv())
    utils::data(list = dataset_name, package = "bribeR", envir = env)
    env[[object_name]]
  }

  transcript_index       <- .load_pkg_data("transcript_index")
  speakers_df            <- .load_pkg_data("speakers_per_transcript")
  topic_descriptions     <- .load_pkg_data("topic_descriptions")
  speaker_info_raw       <- .load_pkg_data("speakers")

  # ---- 1) Resolve transcript directory --------------------------------------
  if (is.null(transcript_dir)) {
    transcript_dir <- system.file("data-raw", "transcripts", package = "bribeR")
  }

  # ---- 2) Optional Montesinos image -----------------------------------------
  montesinos_image_path <- system.file("images", "montesinos.PNG", package = "bribeR")
  if (montesinos_image_path == "" && file.exists(file.path("inst", "images", "montesinos.PNG"))) {
    montesinos_image_path <- file.path("inst", "images", "montesinos.PNG")
  }

  has_img <- nzchar(montesinos_image_path) && file.exists(montesinos_image_path)
  if (has_img) {
    shiny::addResourcePath(
      "briber_images",
      normalizePath(dirname(montesinos_image_path))
    )
    montesinos_image <- file.path("/briber_images", basename(montesinos_image_path))
  } else {
    montesinos_image <- NULL
  }

  # ---- Tooltip style for visInteraction -------------------------------------
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

  # ---- 3) Build UI ----------------------------------------------------------
  ui <- shiny::fluidPage(
    shiny::titlePanel("Transcript-Topic-Speaker Network"),
    shiny::tabsetPanel(
      shiny::tabPanel(
        "Speaker-Topic Network",
        shiny::fluidRow(
          shiny::column(
            width = 12,
            visNetwork::visNetworkOutput("speaker_topic_network", height = "700px")
          )
        ),
      ),
      shiny::tabPanel(
        "Speaker Co-Appearance Network",
        visNetwork::visNetworkOutput("speaker_co_network", height = "700px")
      )
    ),
    shiny::fluidRow(
      shiny::column(width = 12, shiny::br(), shiny::uiOutput("type_legend"))
    )
  )

  # ---- 4) Server ------------------------------------------------------------
  server <- function(input, output, session) {

    # How many transcripts each speaker appears in, counted from the transcript
    # files. Empty when no transcript directory is available.
    speaker_frequency <- {
      if (!is.null(transcript_dir) && nzchar(transcript_dir) && dir.exists(transcript_dir)) {
        files <- fs::dir_ls(transcript_dir, regexp = "\\.(csv|tsv)$", recurse = TRUE)
        sf <- purrr::map_dfr(files, function(path) {
          ext <- tools::file_ext(path)
          df <- if (identical(ext, "csv")) {
            readr::read_csv(path, col_types = readr::cols())
          } else if (identical(ext, "tsv")) {
            readr::read_tsv(path, col_types = readr::cols())
          } else {
            tibble::tibble()
          }
          if (!("speaker_std" %in% names(df))) {
            return(tibble::tibble(speaker_std = character(), file = character()))
          }
          df |>
            dplyr::filter(!is.na(.data$speaker_std), .data$speaker_std != "") |>
            dplyr::distinct(.data$speaker_std) |>
            dplyr::mutate(file = basename(path))
        })
        sf |>
          dplyr::distinct(.data$speaker_std, .data$file) |>
          dplyr::count(.data$speaker_std, name = "conversation_count")
      } else {
        tibble::tibble(speaker_std = character(), conversation_count = integer())
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
      dplyr::select("id", tidyselect::starts_with("topic_")) |>
      tidyr::pivot_longer(
        tidyselect::starts_with("topic_"),
        names_to = "topic",
        values_to = "included"
      ) |>
      dplyr::filter(.data$included == 1L) |>
      dplyr::mutate(
        id    = as.character(.data$id),
        topic = stringr::str_remove(.data$topic, "^topic_")
      )

    # === Speakers reshape ===
    speaker_long <- speakers_df |>
      tidyr::pivot_longer(
        cols = -"id",
        names_to = "speaker_col",
        values_to = "speaker"
      ) |>
      # desconocido is a placeholder for any unidentified speaker rather than
      # one person, so it is left out of the network
      dplyr::filter(!is.na(.data$speaker), .data$speaker != "",
                    .data$speaker != "desconocido") |>
      dplyr::mutate(
        id      = as.character(.data$id),
        speaker = stringr::str_trim(.data$speaker)
      )

    # === Edges: Speaker -> Topic ===
    edges_speaker_topic <- speaker_long |>
      # one row per speaker-topic pair: a transcript has many of each
      dplyr::inner_join(long_topics, by = "id", relationship = "many-to-many") |>
      dplyr::mutate(speaker_std = .data$speaker) |>
      dplyr::distinct(.data$speaker_std, .data$topic) |>
      dplyr::left_join(
        speaker_frequency |>
          dplyr::mutate(speaker_std = stringr::str_to_lower(.data$speaker_std)),
        by = "speaker_std"
      ) |>
      dplyr::transmute(
        from  = .data$speaker_std,
        to    = .data$topic,
        width = pmax(1, log1p(dplyr::coalesce(.data$conversation_count, 0)))
      )

    # === Speaker pairs behind the faint co-appearance edges ===
    # Drawn in grey on the speaker-topic view so that speakers sharing a
    # transcript are pulled together by the layout.
    speaker_pairs_topic_net <- speaker_long |>
      dplyr::select("id", "speaker") |>
      dplyr::distinct() |>
      dplyr::group_by(.data$id) |>
      dplyr::filter(dplyr::n() > 1) |>
      dplyr::summarise(
        pairs = list(combn(.data$speaker, 2, simplify = FALSE)),
        .groups = "drop"
      ) |>
      tidyr::unnest("pairs") |>
      dplyr::mutate(
        from = purrr::map_chr(.data$pairs, 1),
        to   = purrr::map_chr(.data$pairs, 2)
      ) |>
      dplyr::select("from", "to") |>
      dplyr::filter(.data$from != .data$to)

    edges_placeholder <- speaker_pairs_topic_net |>
      dplyr::mutate(
        edge_id = paste(
          pmin(.data$from, .data$to),
          pmax(.data$from, .data$to),
          sep = "~~"
        )
      ) |>
      dplyr::distinct(.data$edge_id, .keep_all = TRUE) |>
      dplyr::select(-"edge_id") |>
      dplyr::group_by(.data$from, .data$to) |>
      dplyr::summarise(weight = dplyr::n(), .groups = "drop") |>
      dplyr::mutate(
        color = "#bbbbbb",
        width = pmax(1, log1p(.data$weight) / 2)
      )

    # === Speaker pairs for co-appearance network ===
    speaker_pairs <- speaker_long |>
      dplyr::select("id", "speaker") |>
      dplyr::distinct() |>
      dplyr::group_by(.data$id) |>
      dplyr::filter(dplyr::n() > 1) |>
      dplyr::summarise(
        pairs = list(combn(.data$speaker, 2, simplify = FALSE)),
        .groups = "drop"
      ) |>
      tidyr::unnest("pairs") |>
      dplyr::mutate(
        from = purrr::map_chr(.data$pairs, 1),
        to   = purrr::map_chr(.data$pairs, 2)
      ) |>
      dplyr::select("from", "to") |>
      dplyr::filter(.data$from != .data$to)

    edges_speaker_co <- speaker_pairs |>
      dplyr::mutate(
        edge_id = paste(
          pmin(.data$from, .data$to),
          pmax(.data$from, .data$to),
          sep = "~~"
        )
      ) |>
      dplyr::distinct(.data$edge_id, .keep_all = TRUE) |>
      dplyr::select(-"edge_id") |>
      dplyr::group_by(.data$from, .data$to) |>
      dplyr::summarise(weight = dplyr::n(), .groups = "drop") |>
      dplyr::mutate(width = pmax(1, log1p(.data$weight)))

    # === Speaker nodes, from the roster plus the transcript counts ===
    nodes_speaker_base <- speaker_long |>
      dplyr::transmute(id = stringr::str_trim(.data$speaker)) |>
      dplyr::distinct()

    speaker_info <- speaker_info_raw |>
      dplyr::mutate(
        type = stringr::str_trim(.data$type),
        # a speaker with no recorded type is shown as "other"
        type = dplyr::if_else(is.na(.data$type) | .data$type == "", "other", .data$type),
        name = dplyr::coalesce(.data$speaker, .data$speaker_std)
      )

    nodes_speaker_st <- nodes_speaker_base |>
      dplyr::left_join(
        speaker_info |>
          dplyr::mutate(
            speaker_std = stringr::str_trim(.data$speaker_std),
            position    = dplyr::coalesce(.data$position, "No info"),
            type        = dplyr::if_else(
              is.na(.data$type) | .data$type == "",
              "other",
              .data$type
            )
          ),
        by = dplyr::join_by(id == speaker_std)
      ) |>
      dplyr::left_join(
        speaker_frequency |>
          dplyr::mutate(speaker_std = stringr::str_to_lower(.data$speaker_std)),
        by = dplyr::join_by(id == speaker_std)
      ) |>
      dplyr::mutate(
        group = "Speaker",
        color = type_colors[.data$type],
        color = ifelse(is.na(.data$color), type_colors[["other"]], .data$color),
        # Use display name as label so nodesIdSelection dropdown shows it via
        # useLabels = TRUE. On-graph text is suppressed via font.size = 0.
        label = dplyr::coalesce(
          dplyr::na_if(stringr::str_trim(.data$name), ""),
          .data$id
        ),
        font.size = 0,
        value = pmax(1, log1p(dplyr::coalesce(.data$conversation_count, 0))),
        title = paste0(
          "<b>", dplyr::coalesce(.data$name, .data$id), "</b><br>",
          "<b>Standardized ID:</b> ", .data$id, "<br>",
          "<b>Type:</b> ", dplyr::coalesce(.data$type, "other"), "<br>",
          "<b>Position:</b> ", dplyr::coalesce(.data$position, "No info"), "<br>",
          "<b>Transcripts:</b> ", dplyr::coalesce(as.character(.data$conversation_count), "0")
        )
      ) |>
      dplyr::select(
        "id", "group", "title", "color",
        "label", "font.size", "value", "name"
      ) |>
      dplyr::distinct(.data$id, .keep_all = TRUE)

    # === Build speaker dropdown map: node id -> display name ================
    # useLabels = TRUE in nodesIdSelection reads the node `label` column, which
    # holds the display name. `values` restricts the dropdown to speakers, so
    # that topic nodes are left out of it. The dropdown lists speakers in the
    # order of `values`, which is alphabetical by display name.
    speaker_dropdown_values <- nodes_speaker_st$id[stringr::str_order(nodes_speaker_st$label)]

    # Drop helper `name` column before passing nodes to visNetwork
    nodes_speaker_st <- nodes_speaker_st |>
      dplyr::select(-"name")

    # Add Montesinos image properties
    if (!has_img) {
      nodes_speaker_st <- nodes_speaker_st |>
        dplyr::mutate(
          shape       = "dot",
          image       = NA_character_,
          size        = NA_real_,
          borderWidth = NA_real_
        )
    } else {
      nodes_speaker_st <- nodes_speaker_st |>
        dplyr::mutate(
          shape       = dplyr::if_else(.data$id == "montesinos", "circularImage", "dot"),
          image       = dplyr::if_else(.data$id == "montesinos", montesinos_image, NA_character_),
          size        = dplyr::if_else(.data$id == "montesinos", 60, NA_real_),
          borderWidth = dplyr::if_else(.data$id == "montesinos", 0, NA_real_)
        )
    }

    # === Topic nodes ===
    nodes_topic_st <- long_topics |>
      dplyr::transmute(id = .data$topic) |>
      dplyr::distinct() |>
      dplyr::left_join(
        topic_descriptions |>
          dplyr::rename(topic = "topics", description = "descriptions") |>
          dplyr::mutate(topic = stringr::str_remove(.data$topic, "^topic_")),
        by = dplyr::join_by(id == topic)
      ) |>
      dplyr::mutate(
        group = "Topic",
        label = "",
        font.size = 0,
        title = paste0(
          "<b>",
          stringr::str_to_title(stringr::str_replace_all(.data$id, "_", " ")),
          "</b><br>",
          .data$description
        ),
        value = 300,
        color = "maroon"
      ) |>
      dplyr::select("id", "group", "title", "value",
                    "color", "label", "font.size") |>
      dplyr::distinct(.data$id, .keep_all = TRUE)

    # === Combined nodes for Speaker-Topic view ===
    nodes_st <- dplyr::bind_rows(
      nodes_speaker_st |>
        dplyr::select(
          "id", "group", "title", "color",
          "label", "font.size", "value", "shape",
          "image", "size", "borderWidth"
        ),
      nodes_topic_st |>
        dplyr::mutate(shape = "dot") |>
        dplyr::select(
          "id", "group", "title", "color",
          "label", "font.size", "value", "shape"
        )
    ) |>
      dplyr::distinct(.data$id, .keep_all = TRUE)

    # === Speaker-Topic Network ===
    output$speaker_topic_network <- visNetwork::renderVisNetwork({
      visNetwork::visNetwork(
        nodes_st,
        dplyr::bind_rows(
          edges_speaker_topic |>
            dplyr::mutate(color = NA_character_),
          edges_placeholder
        )
      ) |>
        visNetwork::visNodes(
          shape = "dot",
          shapeProperties = list(
            useImageSize = FALSE,
            useBorderWithImage = TRUE
          )
        ) |>
        visNetwork::visEdges(
          arrows = "none",
          color = list(color = "grey")
        ) |>
        visNetwork::visOptions(
          highlightNearest = TRUE,
          nodesIdSelection = list(
            enabled   = TRUE,
            values    = speaker_dropdown_values,
            useLabels = TRUE,
            style     = "width: 250px;",
            main      = "Select a speaker"
          )
        ) |>
        visNetwork::visInteraction(
          tooltipStyle = tooltip_style
        ) |>
        visNetwork::visPhysics(
          solver = "forceAtlas2Based",
          stabilization = TRUE
        ) |>
        visNetwork::visLayout(randomSeed = 42) |>
        visNetwork::visEvents(
          stabilizationIterationsDone =
            "function () { this.setOptions({ physics: false }); }"
        )
    })

    # === Speaker Co-Appearance Network ===
    output$speaker_co_network <- visNetwork::renderVisNetwork({
      visNetwork::visNetwork(
        nodes_speaker_st |>
          dplyr::select(
            "id", "group", "title", "color",
            "label", "font.size", "value", "shape",
            "image", "size", "borderWidth"
          ),
        edges_speaker_co
      ) |>
        visNetwork::visNodes(
          shape = "dot",
          shapeProperties = list(
            useImageSize = FALSE,
            useBorderWithImage = TRUE
          )
        ) |>
        visNetwork::visEdges(
          arrows = "none",
          color = list(color = "black")
        ) |>
        visNetwork::visOptions(
          highlightNearest = TRUE,
          nodesIdSelection = list(
            enabled   = TRUE,
            values    = speaker_dropdown_values,
            useLabels = TRUE,
            style     = "width: 250px;",
            main      = "Select a speaker"
          )
        ) |>
        visNetwork::visInteraction(
          tooltipStyle = tooltip_style
        ) |>
        visNetwork::visPhysics(
          solver = "forceAtlas2Based",
          stabilization = TRUE
        ) |>
        visNetwork::visLayout(randomSeed = 42) |>
        visNetwork::visEvents(
          stabilizationIterationsDone =
            "function () { this.setOptions({ physics: false }); }"
        )
    })

    # === Legend ===
    output$type_legend <- shiny::renderUI({
      all_colors <- c(type_colors, "Topics" = "maroon")
      legend_items <- purrr::map2_chr(
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
            stringr::str_to_title(type), "</span></div>"
          )
        }
      )
      shiny::HTML(
        paste(
          "<b>Speaker Types and Topics</b><br><div style='margin-top: 5px;'>",
          paste(legend_items, collapse = ""),
          "</div>"
        )
      )
    })
  }

  shiny::shinyApp(ui = ui, server = server)
}
