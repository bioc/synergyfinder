% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/calculate_sensitivity_score.R
\name{.Own_log2}
\alias{.Own_log2}
\title{CSS Facilitate Function - Log (nature based) Calculation L.4 Model}
\usage{
.Own_log2(x)
}
\arguments{
\item{x}{A numeric value. It is relative IC50 for the curve. The fitted
parameter e from \code{\link[drc]{L.4}} model.}
}
\value{
A numeric value. It is ln(1+exp(x))
}
\description{
This function calculates ln(1+exp(x)) to be used in \link{.ScoreCurve_L4}
function
}
\author{
\itemize{
  \item Shuyu Zheng \email{shuyu.zheng@helsinki.fi}
  \item Jing Tang \email{jing.tang@helsinki.fi}
}
}
