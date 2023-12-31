# SynergyFinder
#
# Functions in this page:
# PlotSensitivitySynergy: Plot Sensitive-Synergy plot for all the combinations in
#                       the input data

#' Plot Sensitive-Synergy Plot for All the Combinations in the Input Data
#' 
#' This function will generate a scatter plot for all the combinations in the
#' input data. The x-axis is the Combination Sensitive score (CSS).
#'
#' @param data A list object has been processed by functions:
#'   \code{\link{ReshapeData}}, \code{\link{CalculateSynergy}}, and 
#'   \code{\link{CalculateSensitivity}}.
#' @param plot_synergy A character value. It indicates the synergy score for
#'   visualization. The available values are: "ZIP", "HSA", Bliss", "Leowe".
#' @param point_size A numeric value. It indicates the size of points. The unit
#'   is "mm"
#' @param point_color An R color value. It indicates the color for the points.
#' @param show_labels A logic value. It indicates whether to show the labels
#'   along with points or not.
#' @param point_label_color An R color value. It indicates the color for the
#'   label of data points.
#' @param label_size A numeric value. It controls the size of the labels in "pt"
#' @param dynamic A logical value. If it is \code{TRUE}, this function will
#'   use \link[plotly]{plot_ly} to generate an interactive plot. If it is
#'   \code{FALSE}, this function will use \link[lattice]{wireframe} to generate
#'   a static plot.
#' @param plot_title A character value. It specifies the plot title. If it is
#'   \code{NULL}, the function will automatically generate a title.
#' @param axis_line A logical value. Whether to show the axis lines and ticks.
#' @param text_size_scale A numeric value. It is used to control the size
#'   of text for axis in the plot. All the text size will multiply by this
#'   scale factor.
#' 
#' @return A ggplot object, while \code{dynamic = FALSE}. A plotly object,
#'   while \code{dynamic = TRUE}.
#'
#' @author
#' \itemize{
#'   \item Shuyu Zheng \email{shuyu.zheng@helsinki.fi}
#'   \item Jing Tang \email{jing.tang@helsinki.fi}
#' }
#' 
#' @export
#'
#' @examples
#' data("mathews_screening_data")
#' data <- ReshapeData(mathews_screening_data)
#' data <- CalculateSynergy(data, method = c("ZIP"))
#' data <- CalculateSensitivity(data)
#' PlotSensitivitySynergy(data, plot_synergy = "ZIP")
PlotSensitivitySynergy <- function(data,
                                 plot_synergy,
                                 point_size = 1,
                                 point_color = "#2D72AD",
                                 show_labels = FALSE,
                                 point_label_color = "#2D72AD",
                                 label_size = 10,
                                 dynamic = FALSE,
                                 plot_title = NULL,
                                 axis_line = FALSE,
                                 text_size_scale = 1){
  plot_table <- data$drug_pairs
  # 1. Check the input data
  # Data structure of 'data'
  if (!is.list(data)) {
    stop("Input data is not in list format!")
  }
  if (!all(c("drug_pairs", "response") %in% names(data))) {
    stop("Input data should contain at least tow elements: 'drug_pairs' and 
         'response'. Please prepare your data with 'ReshapeData' function.")
  }
  if (! "synergy_scores" %in% names(data)){
    stop("Please calculate the synergy scores with function 'CalculateSynergy'")
  }
  # Parameter 'plot_synergy'
  avail_value <- colnames(plot_table)[endsWith(colnames(plot_table),"_synergy")]
  avail_value <- c(avail_value, sub("_synergy", "", avail_value))
  if (!plot_synergy %in% avail_value) {
    stop("The parameter 'plot_synergy = ", plot_synergy, "' is not available.",
         " Avaliable values are '", paste(avail_value, collapse = ", "),
         "'. Alternativly calculate the synergy scores with function",
         " 'CalculateSynergy'")
  }
  if (!grepl("_synergy", plot_synergy)) {
    plot_synergy <- paste0(plot_synergy, "_synergy")
  }
  # Check CSS score in data 
  if (!"css" %in% colnames(plot_table)) {
    stop("There is no Combination Sensitivity Score (CSS) in input data. ",
         "Please run function 'CalculateSensitivity' to calculate it.")
  }
  
  # Plot title
  if (is.null(plot_title)) {
    plot_title <- paste0(
      sub("_synergy", "", plot_synergy),
      " - CSS")
  }

  
  plot_table <- plot_table %>%
    tidyr::unite("label", block_id, dplyr::starts_with("drug"), sep = "\n") %>% 
    dplyr::select(synergy = !!plot_synergy, css, label) 
  
  if (dynamic) {
    if (show_labels) {
      p <- plotly::plot_ly(
        x = plot_table$css,
        y = plot_table$synergy,
        cliponaxis = FALSE,
        type = "scatter",
        text = plot_table$label,
        # hoverinfo = "text",
        mode = "markers+text",
        textposition = "top center",
        marker = list(
          size = 3.7795275591 * point_size, # mm to px
          color = point_color
        ),
        textfont = list(
          size = label_size, 
          color = point_label_color
        )
      )
    } else {
      p <- plotly::plot_ly(
        x = plot_table$css,
        y = plot_table$synergy,
        type = "scatter",
        hovertext = plot_table$label,
        mode = "markers",
        marker = list(
          size = 3.7795275591 * point_size, # mm to px
          color = point_color
        )
      )
    }
    p <- p %>%
      plotly::layout(
        title = list(
          text = paste0("<b>", plot_title, "</b>"),
          tickfont = list(
            size = 18 * text_size_scale,
            family = "arial"
          ),
          y = 0.99
        ),
        xaxis = list(
          title = paste0("Combination Sensitivity Score"),
          tickfont = list(
            size = 12 * text_size_scale,
            family = "arial"
          ),
          ticks = ifelse(axis_line, "outside", "none"),
          showline = axis_line,
          showspikes = FALSE
        ),
        yaxis = list(
          title = paste0("Synergy Score"),
          tickfont = list(
            size = 12 * text_size_scale,
            family = "arial"
          ),
          ticks = ifelse(axis_line, "outside", "none"),
          showline = axis_line,
          showspikes = FALSE
        )
      ) %>% 
      plotly::config(
        toImageButtonOptions = list(
          format = "svg",
          filename = plot_title,
          width = 1000,
          height = 500,
          scale = 1
        )
      ) 
  } else {
    p <- ggplot2::ggplot(
      data = plot_table, 
      mapping = aes(x = css, y = synergy)
      ) +
      ggplot2::geom_point(
        colour = point_color,
        size = point_size
      )
    if (show_labels) {
      p <- p +
        ggrepel::geom_text_repel(
          aes(label = label),
          colour = point_label_color,
          point.padding = 0.25,
          max.overlaps = 30,
          size = .Pt2mm(label_size),
          fontface="bold",
          show.legend=FALSE
        ) 
    }
    p <- p +
      labs(
        title = plot_title,
        x = "Combination Sensitivity Score",
        y = paste0("Synergy Score")
      ) +
      theme_classic() +
      theme(
        panel.background = ggplot2::element_rect(
          fill = "white",
          colour = "white",
          size = 2,
          linetype = "solid"
        ),
        panel.grid.major = ggplot2::element_line(
          size = 0.5,
          linetype = 'solid',
          colour = "#DFDFDF"
        ), 
        panel.grid.minor = ggplot2::element_line(
          size = 0.25,
          linetype = 'solid',
          colour = "#DFDFDF"
        ),
        plot.title = ggplot2::element_text(
          size = 13.5 * text_size_scale,
          face = "bold",
          hjust = 0.5
        ),
        axis.text = ggplot2::element_text(
          size = 10 * text_size_scale
        ),
        axis.title = ggplot2::element_text(
          size = 10 * text_size_scale
        )
      )
    
    if (axis_line){
      p <- p +
        ggplot2::theme(
          axis.ticks = ggplot2::element_line(),
          axis.line = ggplot2::element_line()
        )
    } else {
      p <- p +
        ggplot2::theme(
          axis.ticks = ggplot2::element_blank(),
          axis.line = ggplot2::element_blank()
        )
    }
  }
  return(p)
}