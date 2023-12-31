% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/calculate_sensitivity_score.R
\name{CalculateRI}
\alias{CalculateRI}
\title{Calculate Relative Inhibition (RI) for Dose-Response Curve}
\usage{
CalculateRI(df)
}
\arguments{
\item{df}{A data frame. It contains two variables:
\itemize{
  \item \strong{dose} the concentrations of drugs.
  \item \strong{response} the response of cell lines at corresponding doses.
  We use inhibition rate of cell line growth to measure the response.
}}
}
\value{
A numeric value. It is the RI score for input dose-response curve.
}
\description{
Function \code{CalculateRI} calculates cell line sensitivity to a drug or a
combination of drugs from dose response curve.
}
\details{
This function measures the sensitivity by calculating the Area Under Curve
(AUC) according to the dose response curve. The lower border is chosen as
lowest non-zero concentration in the dose response data.
}
\examples{
# LL.4
df <- data.frame(dose = c(0, 0.1954, 0.7812, 3.125, 12.5, 50),
                 response = c(2.95, 3.76, 18.13, 28.69, 46.66, 58.82))
RI <- CalculateRI(df)
}
\author{
\itemize{
  \item Shuyu Zheng \email{shuyu.zheng@helsinki.fi}
  \item Jing Tang \email{jing.tang@helsinki.fi}
}
}
