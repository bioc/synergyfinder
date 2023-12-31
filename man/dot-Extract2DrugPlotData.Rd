% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/plot_two_drugs.R
\name{.Extract2DrugPlotData}
\alias{.Extract2DrugPlotData}
\title{Extract Data for 2 Drug Combination Plots}
\usage{
.Extract2DrugPlotData(
  data,
  plot_block = 1,
  drugs = c(1, 2),
  plot_value = "response",
  statistic = NULL
)
}
\arguments{
\item{data}{A list object generated by function \code{\link{ReshapeData}}.}

\item{plot_block}{A character/integer. It indicates the block ID for the
block to visualize.}

\item{drugs}{A vector of characters or integers with length of 2. It contains
the index for two drugs to plot. For example, \code{c(1, 2)} indicates to
plot "drug1" and "drug2" in the input \code{data}.}

\item{plot_value}{A character value. It indicates the value to be visualized.
If the \code{data} is the direct output from \link{ReshapeData}, the values
for this parameter are:
\itemize{
  \item \strong{response_origin} The original response value in input data.
  It might be \% inhibition or \% viability.
  \item \strong{response} The \% inhibition after preprocess by function 
  \link{ReshapeData}
}
If the \code{data} is the output from \link{CalculateSynergy}, following
values are also available:
\itemize{
  \item \strong{ZIP_ref, Bliss_ref, HSA_ref, Loewe_ref} The reference
  additive effects calculated by ZIP, Bliss, HSA or Loewe model,
  respectively.
  \item \strong{ZIP_synergy, Bliss_synergy, HSA_synergy, Loewe_synergy}
  The synergy score calculated by ZIP, Bliss, HSA or Loewe model,
  respectively.
  \item \strong{ZIP_fit} The response fitted by ZIP model.
}}

\item{statistic}{A character or NULL. It indicates the statistics printed
in the plot while there are replicates in input data. Available values are:
\itemize{
  \item \strong{sem} Standard error of mean;
  \item \strong{ci} 95\% confidence interval.
}
If it is \code{NULL}, no statistics will be printed.}
}
\value{
A data frame. It contains the concentrations for selected drugs, the
  selected values for plotting, and the text for printing on the heatmap.
}
\description{
Extract Data for 2 Drug Combination Plots
}
\author{
\itemize{
  \item Shuyu Zheng \email{shuyu.zheng@helsinki.fi}
  \item Jing Tang \email{jing.tang@helsinki.fi}
}
}
