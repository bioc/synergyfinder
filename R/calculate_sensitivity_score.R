# Copyright Shuyu Zheng and Jing Tang - All Rights Reserved
# Unauthorized copying of this file, via any medium is strictly prohibited
# Proprietary and confidential
# Written by Shuyu Zheng <shuyu.zheng@helsinki.fi>, March 2021
#
# SynergyFinder
#
# Functions on this page:
#
# CalculateSensitivity: Calculate the synergy scores for drug combinations
# CalculateCSS: Calculate the synergy scores for drug combinations
# CalculateRI: Calculate sensitivity score (relative inhibition)
# ImputeIC50: Impute missing value at IC50 concentration of drug
# PredictResponse: Predict response value at certain drug dose
# CalculateIC50: Transform IC50 from coefficients from fitted dose-response
#                model
#
# Auxiliary functions:
# .ScoreCurve/.ScoreCurve_L4: facility functions for CalculateRI
# .Own_log/.Own_log2: facility functions for CalculateRI

#' Calculate the Sensitivity Scores for Drug Combinations
#'
#' \code{CalculateSensitivity} is the main function for calculating sensitivity
#' scores from the dose response matrix. It will return the RI
#' (relative inhibition), IC50 (relative IC50) for each drug in the combination.
#' It will also calculate the CSS (combination sensitivity score) for each drug
#' while other drugs are at their IC50 and the CSS for the whole combination
#' matrix.
#'
#' @param data A list object generated by function \code{\link{ReshapeData}}.
#' @param adjusted A logical value. If it is \code{TRUE}, the
#'   'adjusted.response.mats' will be used to calculate synergy scores. If it is
#'   \code{FALSE}, the raw data ('dose.response.mats') will be used to calculate
#'   synergy scores.
#' @param correct_baseline  A character value. It indicates the method used for
#'   baseline correction. Available values are:
#'   \itemize{
#'     \item \strong{non} No baseline correction.
#'     \item \strong{part} Adjust only the negative values in the matrix.
#'     \item \strong{all} Adjust all values in the matrix.
#'   }
#' @param iteration An integer. It indicates the number of iterations for
#'   bootstrap on data with replicates.
#' @param seed An integer or NULL. It is used to set the random seed in synergy
#'   scores calculation on data with replicates. 
#'
#' @return  This function will add columns into \code{data$drug_pairs} table.
#'   The columns are:
#'   \itemize{
#'     \item \strong{ic50_1/2/...} Relative IC50 for drug 1, 2, ...
#'     \item \strong{ri_1/2/...} Relative Inhibition (RI) for drug 1, 2, ...
#'     \item \strong{css1_ic502/...} CSS score of drug 1 while fixing drug 2
#'       at its IC50.
#'     \item \strong{css} Over all CSS score for the whole block. It's the mean
#'       value of the CSS for all drug pairs in the combination. 
#'  }
#'  If there are replicates in the block, this function will add one table named
#'  as "sensitivity_scores_statistics" for the statistics of the values
#'  mentioned about into the input \code{data} list.
#'
#' @export
#' 
#' @author
#' \itemize{
#'   \item Shuyu Zheng \email{shuyu.zheng@helsinki.fi}
#'   \item Jing Tang \email{jing.tang@helsinki.fi}
#' }
#' 
#' @examples
#' data("ONEIL_screening_data")
#' data <- ReshapeData(ONEIL_screening_data, data_type = "inhibition")
#' data <- CalculateSensitivity(data)
CalculateSensitivity <- function(data,
                                 adjusted = TRUE,
                                 correct_baseline = "non",
                                 iteration = 10,
                                 seed = 123) {
  options(scipen = 999)
  # 1. Check the input data
  if (!is.list(data)) {
    stop("Input data is not in list format!")
  }
  if (!all(c("drug_pairs", "response") %in% names(data))) {
    stop("Input data should contain at least tow elements: 'drug_pairs' and 
         'response'. Please prepare your data with 'ReshapeData' function.")
  }
  
  # 2. Select the dose response table for plotting.
  if (adjusted) {
    response <- data$response %>%
      dplyr::select(-response_origin)
  } else {
    response <- data$response %>%
      dplyr::select(-response) %>% 
      dplyr::rename(response = response_origin)
  }

  # 3. Calculate RI and CSS
  blocks <- unique(response$block_id)
  scores <- NULL
  scores_statistics <- NULL
  for (b in blocks) {
    message("Calculating sensitivity scores for block ", b, " ...")
    response_one_block <- response %>% 
      dplyr::filter(block_id == b) %>% 
      dplyr::select(-block_id) %>% 
      dplyr::ungroup()
    concs <- grep("conc\\d", colnames(response_one_block), value = TRUE)
    
    if (data$drug_pairs$replicate[data$drug_pairs$block_id == b]) {
      tmp_iter <- NULL
      set.seed(seed)
      pb <- utils::txtProgressBar(min = 1, max = iteration, style = 3)
      for(i in 1:iteration){
        response_boot <- .Bootstrapping(response_one_block)
        response_boot <- CorrectBaseLine(
          response_boot,
          method = correct_baseline
        )
        # Calculate RI
        single_drug_data <- ExtractSingleDrug(response_boot)
        ri <- suppressWarnings(as.data.frame(lapply(single_drug_data, CalculateRI)))
        colnames(ri) <- sub("conc", "ri_", colnames(ri))
        
        # Calculate IC50 for all drugs
        ic50 <- lapply(
          single_drug_data,
          function(x) {
            model <- suppressWarnings(FitDoseResponse(x))
            coe <- FindModelPar(model)
            type <- FindModelType(model)
            CalculateIC50(coe, type, max(x$dose))
          }) %>% 
          as.data.frame()
        colnames(ic50) <- sub("ri", "ic50", colnames(ri))
        
        # Calculate CSS
        css <- suppressWarnings(CalculateCSS(response_boot, ic50 = ic50))
        
        # Assemble data frame
        tmp <- cbind.data.frame(ic50, ri, css)
        tmp_iter <- rbind.data.frame(tmp_iter, tmp)
        utils::setTxtProgressBar(pb, i)
      }
      message("\n")
      SensMean <- colMeans(tmp_iter)
      tmp <- as.data.frame(as.list(SensMean)) %>%
        dplyr::mutate(block_id = b)
      SensSd <- apply(tmp_iter, 2, stats::sd)
      SensSem <- SensSd / sqrt(iteration)
      SensCI95_left <- apply(tmp_iter, 2, 
                             function(x) stats::quantile(x, probs = 0.025))
      SensCI95_right <- apply(tmp_iter, 2, 
                             function(x) stats::quantile(x, probs = 0.975))
      p_value <- apply(
        tmp_iter[, !grepl("ic50", colnames(tmp_iter), fixed = TRUE)],
        2, 
        function(x) {
          z <- abs(mean(x)) / stats::sd(x)
          p <- exp(-0.717 * z - 0.416 * z ^2)
          p <- formatC(p, format = "e", digits = 2, zero.print = "< 2e-324")
          return(p)
        })
      
      names(SensMean) <- paste0(names(SensMean), "_mean")
      names(SensSd) <- paste0(names(SensSd), "_sd")
      names(SensSem) <- paste0(names(SensSem), "_sem")
      names(SensCI95_left) <- paste0(names(SensCI95_left), "_ci_left")
      names(SensCI95_right) <- paste0(names(SensCI95_right), "_ci_right")
      names(p_value) <-  paste0(names(p_value), "_p_value")
      tmp_sensitivity_statistic <- as.data.frame(
          as.list(
            c(SensMean, SensSd, SensSem,
              SensCI95_left, SensCI95_right, p_value
            )
          )
        ) %>% 
        dplyr::mutate(block_id = b)
      scores <- rbind.data.frame(scores, tmp)
      scores_statistics <- rbind.data.frame(
        scores_statistics,
        tmp_sensitivity_statistic
      )
    } else{
      response_one_block <- CorrectBaseLine(
        response_one_block,
        method = correct_baseline
      )
      # Calculate RI
      single_drug_data <- ExtractSingleDrug(response_one_block)
      ri <- suppressWarnings(as.data.frame(lapply(single_drug_data, CalculateRI)))
      colnames(ri) <- sub("conc", "ri_", colnames(ri))
      
      # Calculate IC50 for all drugs
      ic50 <-lapply(
        single_drug_data,
        function(x) {
          model <- suppressWarnings(FitDoseResponse(x))
          coe <- FindModelPar(model)
          type <- FindModelType(model)
          suppressWarnings(CalculateIC50(coe, type, max(x$dose)))
        }) %>% 
        as.data.frame()
      colnames(ic50) <- sub("ri", "ic50", colnames(ri))
      
      # Calculate CSS
      css <- suppressWarnings(CalculateCSS(response_one_block, ic50 = ic50))
      
      # Assemble data frame
      tmp <- cbind.data.frame(ic50, ri, css) %>% 
        dplyr::mutate(block_id = b)
      scores <- rbind.data.frame(scores, tmp)
    }
  }
  ## 4. Save data into the list
  data$drug_pairs <- data$drug_pairs %>% 
    dplyr::select(
      block_id, 
      setdiff(colnames(data$drug_pairs), colnames(scores))
    ) %>% 
    dplyr::left_join(scores, by = "block_id")
  if (length(scores_statistics) != 0) {
    data$sensitivity_scores_statistics <- dplyr::select(
      scores_statistics,
      block_id,
      dplyr::everything()
    )
  }
  return(data)
}

#' Calculate Combination Sensitivity Score
#' 
#' This function will calculate the Combination Sensitivity Score (CSS) for a
#' drug combination block.
#'
#' @param response A data frame. It must contain the columns: "conc1", "conc2",
#'   ..., for the concentration of the combined drugs and "response" for the
#'   observed \%inhibition at certain combination.
#' @param ic50 A list. It contains the relative IC50 for all the drugs in the
#'   combination.
#'
#' @return A data frame. It contains the CSS for each drug will one of the other
#'   drugs is at its IC50 and summarized CSS for the whole block.
#'   
#' @author
#' \itemize{
#'   \item Shuyu Zheng \email{shuyu.zheng@helsinki.fi}
#'   \item Jing Tang \email{jing.tang@helsinki.fi}
#' }
#' 
#' @export
CalculateCSS <- function(response, ic50) {
  concs <- grep("conc\\d", colnames(response), value = TRUE)
  # Calculate CSS for all drug pairs
  conc_zero <- apply(
    dplyr::select(response, - response), 
    1,
    function(x) {
      sum(x != 0) <= 2
    })
  response_two_drugs <- response[conc_zero, ]
  
  conc_pairs <- utils::combn(concs, 2)
  
  css <- vector("list", 2 * ncol(conc_pairs))
  names(css) <- apply(
    conc_pairs, 2, 
    function(x){
      c(paste0(sub("conc", "css", x[1]), sub("conc", "_ic50", x[2])),
        paste0(sub("conc", "css", x[2]), sub("conc", "_ic50", x[1])))
    }
  )
  for (i in 1:ncol(conc_pairs)) {
    pair <- conc_pairs[, i]
    # css_c <- pair[1]
    # ic50_c <- pair[2]
    other_concs <- setdiff(concs, pair)
    if (length(other_concs) > 0) {
      other_concs <- response_two_drugs %>% 
        dplyr::ungroup() %>% 
        dplyr::select(dplyr::all_of(other_concs)) %>% 
        rowSums()
      response_pair <- response_two_drugs[other_concs == 0, ] %>% 
        dplyr::select(dplyr::all_of(pair), response)
    } else {
      response_pair <- response_two_drugs
    }
    for (css_c in pair) {
      ic50_c <- setdiff(pair, css_c)
      tmp_css <- response_pair %>% 
        dplyr::rename(dose = !!ic50_c) %>% 
        dplyr::group_by(!!as.name(css_c)) %>% 
        tidyr::nest(data = dplyr::all_of(c("dose", "response"))) %>% 
        dplyr::mutate(response = furrr::future_map(
          data, function(x){
          if (nrow(x) == 2) {
            return(x$response[2])
          } else {
            return(
              suppressWarnings(
                PredictResponse(
                  x,
                  dose = ic50[[sub("conc", "ic50_", ic50_c)]]
                )
              )
            )
          }
        },
        .options = furrr::furrr_options(seed = NULL)
        )) %>% 
        dplyr::select(dose = !!as.name(css_c), response) %>% 
        tidyr::unnest(cols = c(response)) %>% 
        CalculateRI()
      css_name <- paste0(
        sub("conc", "css", css_c),
        sub("conc", "_ic50", ic50_c)
      )
      css[[css_name]] <- tmp_css
    }
  }
  css <- as.data.frame(css)
  css$css <- rowMeans(css)
  return(css)
}

#' Calculate Relative Inhibition (RI) for Dose-Response Curve
#'
#' Function \code{CalculateRI} calculates cell line sensitivity to a drug or a
#' combination of drugs from dose response curve.
#'
#' This function measures the sensitivity by calculating the Area Under Curve
#' (AUC) according to the dose response curve. The lower border is chosen as
#' lowest non-zero concentration in the dose response data.
#'
#' @param df A data frame. It contains two variables:
#' \itemize{
#'   \item \strong{dose} the concentrations of drugs.
#'   \item \strong{response} the response of cell lines at corresponding doses.
#'   We use inhibition rate of cell line growth to measure the response.
#' }
#' 
#' @return A numeric value. It is the RI score for input dose-response curve.
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
#' # LL.4
#' df <- data.frame(dose = c(0, 0.1954, 0.7812, 3.125, 12.5, 50),
#'                  response = c(2.95, 3.76, 18.13, 28.69, 46.66, 58.82))
#' RI <- CalculateRI(df)

CalculateRI <- function(df) {
  df <- df[order(df$dose), ]
  df <- df[which(df$dose != 0), ]
  if (nrow(df) == 1) {
    score <- df$response[1]
    res <- score
  } else {
    # If all the response values are same, the curve can not be fitted.
    # Solution: add a small value to the response at highest dosage
    if (stats::var(df$response) == 0) {
      df$response[nrow(df)] <- df$response[nrow(df)] +
        10^-10
    }
    tryCatch({
      model <- drc::drm(response ~ dose, data = df, fct = drc::LL.4(),
                        control = drc::drmc(errorm = FALSE, noMessage = TRUE,
                                            otrace = TRUE))
      fitcoefs <- model$coefficients
      names(fitcoefs) <- NULL
      # Calculate DSS
      score <- round(.ScoreCurve(d = fitcoefs[3] / 100,
                                 c = fitcoefs[2] / 100,
                                 b = fitcoefs[1],
                                 m = log10(fitcoefs[4]),
                                 c1 = log10(min(df$dose)),
                                 c2 = log10(max(df$dose)),
                                 t = 0), 3)
    }, error = function(e) {
      # Skip zero conc, log, drc::L.4()
      # message(e)
      model <<- drc::drm(response ~ log10(dose), data = df, fct = drc::L.4(),
                         control = drc::drmc(errorm = FALSE, noMessage = TRUE,
                                             otrace = FALSE))
      fitcoefs <- model$coefficients
      names(fitcoefs) <- NULL
      score <<- round(.ScoreCurve_L4(d = fitcoefs[3] / 100,
                                     c = fitcoefs[2] / 100,
                                     b = fitcoefs[1],
                                     e = fitcoefs[4],
                                     c1 = log10(min(df$dose)),
                                     c2 = log10(max(df$dose)),
                                     t = 0), 3)
    })
    res <- score
  }
  return(res)
}

#' Impute Missing Value at IC50 Concentration of Drug
#'
#' \code{ImputeIC50} uses the particular experiment's values to predict the
#' missing values at the desired IC50 concentration of the drug.
#
#' This function is only called when trying to fix a drug at its selected IC50
#' concentration where the response values have not been tested in experiment.
#'
#' \code{ImputeIC50} fits dose-response models (with \code{\link[drc]{drm}}
#' function) by fixing the concentrations of the
#' \strong{other} drug successively, and uses each fit to predict the missing
#' value at the combination (missing IC50, fixed conc).
#'
#' @param response.mat A matrix. It contains response value of a block of drug
#'   combination.
#' @param row.ic50 A numeric value. The IC50 value of drug added to rows.
#' @param col.ic50 A numeric value. The IC50 value of drug added to columns.
#'
#' @return A data frame contains all response value at the IC50 concentration
#'   of certein drug. It could be directly passed to function
#'   \code{CalculateRI} for scoring.
#'
#' @author
#' \itemize{
#'   \item Shuyu Zheng \email{shuyu.zheng@helsinki.fi}
#'   \item Jing Tang \email{jing.tang@helsinki.fi}
#' }
#'
#' @export
ImputeIC50 <- function(response.mat, col.ic50, row.ic50) {
  
  colconc <- as.numeric(colnames(response.mat))
  rowconc <- as.numeric(rownames(response.mat))
  n_col <- length(colconc)
  n_row <- length(rowconc)
  
  if (n_row == 2) {
    tempcf_c <- data.frame(dose = colconc, response = response.mat[2, ])
  } else {
    response <- apply(response.mat, 2, function(x){
      df <- data.frame(dose = rowconc, response = x)
      pred <- PredictResponse(df, row.ic50)
      return(pred)
    }
    )
    tempcf_c <- data.frame(dose = colconc, response = response)
  }
  
  if (n_col == 2) {
    tempcf_r <- data.frame(dose = rowconc, response = response.mat[, 2])
  } else {
    response <- apply(response.mat, 1, function(x){
      df <- data.frame(dose = colconc, response = x)
      pred <- PredictResponse(df, col.ic50)
      return(pred)
    }
    )
    tempcf_r <- data.frame(dose = rowconc, response = response)
  }
  
  tempres <- list(tempcf_c = tempcf_c, tempcf_r = tempcf_r)
  return(tempres)
}

#' Calculate Relative IC50 from Fitted Model
#' 
#' This function will calculate the relative IC50 from fitted 4-parameter 
#' log-logistic dose response model.
#'
#' @param coef A numeric vector. It contains the fitted coefficients for
#'   4-parameter log-logistic dose response model.
#' @param type A character value. It indicates the type of model was used for
#'   fitting the dose-response curve. Available values are "L.4" and "LL.4".
#' @param max.conc A numeric value. It indicates the maximum concentration in
#'   the dose-response data
#'
#' @return A numeric value. It is the relative IC50.
#' 
#' @author
#' \itemize{
#'   \item Shuyu Zheng \email{shuyu.zheng@helsinki.fi}
#'   \item Jing Tang \email{jing.tang@helsinki.fi}
#' }
#' 
#' @export
#'
CalculateIC50 <- function(coef, type, max.conc){
  if (type == "LL.4") {
    ic50 <- coef[["e_EC50"]]
  } else if (type == "L.4") {
    ic50 <- exp(coef[["e_log(EC50)"]])
  } else {
    stop("The input 'type = ", type,
         "' is not available. The available values are 'L.4' and 'LL.4'")
  }
  
  if (ic50 > max.conc) {
    ic50 = max.conc
  }
  
  return (ic50)
}

# Auxiliary functions -----------------------------------------------------

#' CSS Facilitate Function - .ScoreCurve for Curves Fitted by LL.4 Model
#'
#' New function used to score sensitivities given either a single-agent or a
#' fixed conc (combination) columns. The function calculates the AUC of the
#' log10-scaled dose-response curve. \strong{IMPORTANT:} note that with
#' \code{\link[drc]{LL.4}} calls, this value is already logged since the
#' input concentrations are logged.
#'
#' @param b A numeric value, fitted parameter b from \code{\link[drc]{LL.4}}
#'   model.
#' @param c A numeric value, fitted parameter c from \code{\link[drc]{LL.4}}
#'   model.
#' @param d A numeric value, fitted parameter d from \code{\link[drc]{LL.4}}
#'   model.
#' @param m A numeric value, relative IC50 for the curve. log10(e), where e is
#'   the fitted parameter e from \code{\link[drc]{LL.4}} model.
#' @param c1 A numeric value, log10(min conc) (this is the minimal nonzero
#'   concentration).
#' @param c2 A numeric value, log10(max conc) (this is the maximal
#'   concentration).
#' @param t A numeric value, threshold (usually set to zero).
#'
#' @return A numeric value, RI or CSS scores.
#'
#' @author
#' \itemize{
#'   \item Shuyu Zheng \email{shuyu.zheng@helsinki.fi}
#'   \item Jing Tang \email{jing.tang@helsinki.fi}
#' }
#'
.ScoreCurve <- function(b, c, d, m, c1, c2, t) {
  int_y <- (((((d - c) * .Own_log(-b, c2, m)) / ((-b) * log(10))) + c * c2) -
              ((((d - c) * .Own_log(-b, c1, m)) / ((-b) * log(10))) + c * c1))
  
  ratio <- int_y / ((1 - t) * (c2 - c1))
  sens <- ratio * 100 # scale by 100
  return(sens)
}

#' CSS Facilitate Function - Log Calculation (nature based) LL.4 Model
#'
#' #' This function calculates ln(1+10^(b*(c-x))) to be used in
#' \code{.ScoreCurve} function
#'
#' @param b A numeric value. It is the fitted parameter b from 
#'   \code{\link[drc]{L.4}} model.
#' @param c A numeric value. It is the fitted parameter c from 
#'   \code{\link[drc]{L.4}} model.
#' @param x A numeric value. It is the relative IC50 for the curve. log10(e), 
#'   where e is the fitted parameter e from \code{\link[drc]{L.4}} model.
#'
#' @return ln(1+10^(b*(c-x)))
#'
#' @author
#' \itemize{
#'   \item Shuyu Zheng \email{shuyu.zheng@helsinki.fi}
#'   \item Jing Tang \email{jing.tang@helsinki.fi}
#' }
#'
.Own_log = function(b, c, x)
{
  arg = 1 + 10^(b*(c-x))
  if(is.infinite(arg)==T) res = b*(c-x)*log(10) else res = log(arg)
  return(res)
}

#' CSS Facilitate Function - .ScoreCurve for Curves Fitted by L.4 Model
#'
#' This function is used to score sensitivities given either a single-agent or a
#' fixed conc (combination) columns. The function calculates the AUC of the
#' log10-scaled dose-response curve.
#'
#' @param b A numeric value, fitted parameter b from \code{\link[drc]{L.4}}
#'   model.
#' @param c A numeric value, fitted parameter c from \code{\link[drc]{L.4}}
#'   model.
#' @param d A numeric value, fitted parameter d from \code{\link[drc]{L.4}}
#'   model.
#' @param e A numeric value, fitted parameter e from \code{\link[drc]{L.4}}
#'   model.
#' @param c1 A numeric value, log10(min conc) (this is the minimal nonzero
#'   concentration).
#' @param c2 A numeric value, log10(max conc) (this is the maximal
#'   concentration).
#' @param t A numeric value, threshold (usually set to zero).
#'
#' @return A numeric value, RI or CSS scores.
#'
#' @author
#' \itemize{
#'   \item Shuyu Zheng \email{shuyu.zheng@helsinki.fi}
#'   \item Jing Tang \email{jing.tang@helsinki.fi}
#' }
#'
.ScoreCurve_L4 <- function(b, c, d, e, c1, c2, t) {
  int_y <- d * (c2 - c1) + ((c - d) / b) *
    (.Own_log2(b * (c2 - e)) - .Own_log2(b * (c1 - e)))
  ratio <- int_y / ((1 - t) * (c2 - c1))
  sens <- ratio * 100 # scale by 100
  return(sens)
}

#' CSS Facilitate Function - Log (nature based) Calculation L.4 Model
#'
#' This function calculates ln(1+exp(x)) to be used in \link{.ScoreCurve_L4}
#' function
#'
#' @param x A numeric value. It is relative IC50 for the curve. The fitted
#'   parameter e from \code{\link[drc]{L.4}} model.
#'
#' @return A numeric value. It is ln(1+exp(x))
#'
#' @author
#' \itemize{
#'   \item Shuyu Zheng \email{shuyu.zheng@helsinki.fi}
#'   \item Jing Tang \email{jing.tang@helsinki.fi}
#' }
#'
.Own_log2 <- function(x){
  arg = 1 + exp(x)
  if(is.infinite(arg)==T) res = x else res = log(arg)
  return(res)
}
