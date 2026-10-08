# Final_use_script.R
# PUS_draft2: Table 1 and Figures 1–3. Updated 2026-10-08.
# Source: R_scripts/260528瀧川ラボミ.qmd, preparing variables and
# multinomial regression with lca; analysis_latent_class.R for Figures 2–3.
# Run from any directory:
# Rscript Final_use_script.R --project-root="/path/to/社会学自由記述分析"
# Optional: --output-dir="/path/to/output" (default: PROJECT/output).
# In RStudio: open PUS_repository.Rproj, then source("run_analysis.R").
# Sourcing this file only defines functions; it does not read data or fit models.
# Dependencies are checked, never installed automatically. Original files are preserved.

required_packages <- c("dplyr", "tidyr", "psych", "poLCA", "nnet",
                       "marginaleffects", "ggplot2", "patchwork", "scales",
                       "openxlsx", "ragg", "xml2", "zip")

check_packages <- function() {
  absent <- required_packages[!vapply(required_packages, requireNamespace,
                                     logical(1), quietly = TRUE)]
  if (length(absent)) stop("Install missing packages before running: ",
                           paste(absent, collapse = ", "))
}

find_project_root <- function(start = getwd()) {
  current <- normalizePath(start, mustWork = TRUE)
  if (!dir.exists(current)) current <- dirname(current)
  repeat {
    if (file.exists(file.path(current, "R_scripts", "Final_use_script.R"))) return(current)
    parent <- dirname(current)
    if (identical(parent, current)) break
    current <- parent
  }
  stop("Cannot find the project. Open PUS_repository.Rproj or supply --project-root=PATH.")
}

read_survey <- function(project_root, input_file = NULL, encoding = "auto") {
  if (is.null(input_file)) {
    input_file <- file.path(project_root, "data", "data.csv")
    if (!file.exists(input_file)) {
      candidates <- list.files(file.path(project_root, "data"),
                               pattern = "241010[.]csv$", full.names = TRUE)
      if (length(candidates) != 1L)
        stop("Place the private survey in data/data.csv, or supply --input=PATH.")
      input_file <- candidates
    }
  }
  input_file <- normalizePath(input_file, mustWork = TRUE)
  encodings <- if (identical(encoding, "auto")) c("UTF-8-BOM", "CP932") else encoding
  errors <- character()
  for (enc in encodings) {
    dat <- tryCatch(withCallingHandlers(
      utils::read.csv(input_file, fileEncoding = enc, check.names = TRUE),
      warning = function(w) stop(conditionMessage(w), call. = FALSE)), error = identity)
    if (inherits(dat, "error")) {
      errors <- c(errors, paste0(enc, ": ", conditionMessage(dat)))
      next
    }
    prefixes <- c(paste0("Q", 1:6, "."),
                  paste0("Q7項目", setdiff(1:10, 4), "."),
                  paste0("Q14項目", 1:10, "."))
    invalid <- prefixes[vapply(prefixes, function(p) sum(startsWith(names(dat), p)) != 1L,
                                logical(1))]
    if (length(invalid)) {
      errors <- c(errors, paste0(enc, ": missing or ambiguous columns: ", paste(invalid, collapse = ", ")))
      next
    }
    if (!nrow(dat)) stop("The survey CSV has no observations.")
    message("Read ", nrow(dat), " survey records (", enc, ")")
    return(list(data = dat, file = input_file, encoding = enc))
  }
  stop("Could not read the survey CSV.\n", paste(errors, collapse = "\n"))
}

class_names <- c("Class 1: Don't Know", "Class 2: Neutral", "Class 3: Low Rating",
                 "Class 4: High Rating", "Class 5: STEM High Rating")
field_names <- c("Medicine", "Psychology", "Literature", "Economics", "Engineering",
                 "Sociology", "Agriculture", "Pol. Science", "Biology", "Physics")
field_vars <- paste0("q14_", c("med", "psy", "lit", "eco", "eng", "soc", "agr", "pol", "bio", "phy"), "3")
rating_names <- c("Don't know", "Not scientific", "Neither", "Scientific")
rating_colors <- stats::setNames(c("#E0E0E0", "#FF6B6B", "#FFE66D", "#4ECDC4"), rating_names)

find_column <- function(dat, prefix) {
  n <- names(dat)[startsWith(names(dat), prefix)]
  if (length(n) != 1L) stop("Expected one column beginning with: ", prefix)
  dat[[n]]
}

prepare_data <- function(dat) {
  q <- lapply(1:6, function(i) find_column(dat, paste0("Q", i, ".")))
  for (i in 1:6) {
    allowed <- list(1:3, 1:52, 1:7, 1:30, 1:11, 1:10)[[i]]
    if (any(!is.na(q[[i]]) & !q[[i]] %in% allowed)) stop("Unexpected Q", i, " codes")
  }
  edu <- dplyr::case_when(q[[3]] %in% 1:2 ~ 1L, q[[3]] %in% 3:5 ~ 2L,
    q[[3]] == 6 & q[[4]] %in% 1:12 ~ 3L,
    q[[3]] == 6 & q[[4]] %in% 13:27 ~ 4L,
    q[[3]] == 6 ~ 5L, q[[3]] == 7 ~ 6L)
  x <- data.frame(row_id = seq_len(nrow(dat)),
    gender = factor(q[[1]], levels = 1:2, labels = c("Male", "Female")),
    age = q[[2]] + 17,
    edu_major_f = factor(edu, levels = 1:6, labels = c("Mid/High School",
      "Vocational/JC", "BA Humanities", "BA Sciences", "BA Other", "Graduate")),
    job4 = factor(c(1,2,2,3,3,1,4,4,4,4,1)[q[[5]]], levels = 1:4,
                  labels = c("Regular", "Non-regular", "Self-employed", "Unemployed")),
    finc_log = log10(c(100,250,350,450,550,650,750,900,1200,1400)[q[[6]]]))
  # Q5=11 retains the original authors' reviewed coding as regular employment.
  # Income band representatives are in JPY 10,000. Q2 exports age codes 1:52.
  for (i in setdiff(1:10, 4)) {
    z <- find_column(dat, paste0("Q7項目", i, "."))
    if (any(!is.na(z) & !z %in% 1:7)) stop("Unexpected Q7 codes")
    x[[paste0("q7_", i)]] <- 8 - z
  }
  for (i in seq_along(field_vars)) {
    z <- find_column(dat, paste0("Q14項目", i, "."))
    if (any(!is.na(z) & !z %in% 1:7)) stop("Unexpected Q14 codes")
    x[[field_vars[i]]] <- factor(c(4,4,3,2,2,1,1)[z], levels = 1:4, labels = rating_names)
  }
  x
}

add_factor_scores <- function(x) {
  items <- paste0("q7_", setdiff(1:10, 4))
  if (anyNA(x[items])) stop("Missing Q7 values: specify a missing-data policy before running.")
  fa <- psych::fa(x[items], nfactors = 3, rotate = "varimax", fm = "minres",
                   scores = "regression")
  # Original solution: MR2=anti-science, MR1=authority, MR3=inequality.
  # Explicit names and signs prevent silently exchanging factor labels.
  map <- c(Factor1_Authoritarian = "MR1", Factor2_AntiScience = "MR2", Factor3_Inequality = "MR3")
  anchors <- c("q7_1", "q7_5", "q7_7")
  if (!all(map %in% colnames(fa$scores))) stop("Unexpected factor solution.")
  for (i in seq_along(map)) {
    if (fa$loadings[anchors[i], map[i]] < 0.3) stop("Factor orientation changed; inspect loadings.")
    x[[names(map)[i]]] <- fa$scores[, map[i]]
  }
  list(data = x, fa = fa)
}

fit_lca <- function(x) {
  keep <- stats::complete.cases(x[field_vars])
  d <- x[keep, field_vars]
  f <- stats::as.formula(paste0("cbind(", paste(field_vars, collapse = ","), ") ~ 1"))
  # Preserve both seed and 2:8 fitting sequence from the original analysis.
  RNGkind("Mersenne-Twister", "Inversion", "Rejection")
  set.seed(123)
  models <- list()
  for (k in 2:8) {
    message("Fitting LCA: ", k, " classes")
    models[[as.character(k)]] <- poLCA::poLCA(f, data = d, nclass = k,
      nrep = 10, maxiter = 1000, tol = 1e-10, na.rm = FALSE, verbose = FALSE)
  }
  fit_row <- function(m, k) data.frame(Classes = as.integer(k), AIC = m$aic,
    BIC = m$bic, Gsq = m$Gsq, logLik = m$llik, iterations = m$numiter)
  original <- dplyr::bind_rows(lapply(names(models), function(k) fit_row(models[[k]], k)))
  # Continue a retained solution that hit the cap. Never change class count
  # automatically. Keep original fit indices for the manuscript comparison.
  for (k in names(models)) {
    if (models[[k]]$numiter >= 1000) {
      message("Continuing capped ", k, "-class solution from its fitted probabilities")
      old <- models[[k]]
      new <- poLCA::poLCA(f, data = d, nclass = as.integer(k), nrep = 1,
        probs.start = old$probs, maxiter = 10000, tol = 1e-10,
        na.rm = FALSE, verbose = FALSE)
      if (new$numiter >= 10000 || new$llik < old$llik - 1e-6)
        stop("LCA continuation failed for ", k, " classes. Inspect convergence.")
      models[[k]] <- new
    }
  }
  best <- models[["5"]]
  # Check original class numbering against the response profiles before labeling.
  mean_p <- Reduce(`+`, best$probs) / length(best$probs)
  if (!identical(as.integer(apply(mean_p[1:4,,drop=FALSE], 1, which.max)), c(1L,3L,2L,4L)))
    stop("LCA labels changed. Inspect probabilities before assigning class names.")
  x$lca_class <- NA_integer_
  x$lca_class[keep] <- best$predclass
  x$lca_class <- factor(x$lca_class, levels = 1:5, labels = class_names)
  list(data = x, models = models, original = original,
    indices = dplyr::bind_rows(lapply(names(models), function(k) fit_row(models[[k]], k))))
}

fit_regression <- function(x) {
  predictors <- c("gender", "age", "edu_major_f", "job4", "finc_log",
    "Factor1_Authoritarian", "Factor2_AntiScience", "Factor3_Inequality")
  keep <- stats::complete.cases(x[c("lca_class", predictors)])
  d <- x[keep, c("lca_class", predictors)]
  f <- stats::reformulate(predictors, response = "lca_class")
  # Raw units match the QMD's fit_multinom_marginal, not its separate
  # standardized coefficient model. Class 1 is the internal logit reference.
  fit <- nnet::multinom(f, data = d, maxit = 100, Hess = TRUE, trace = FALSE, model = TRUE)
  if (fit$convergence != 0) stop("Multinomial regression did not converge.")
  ame <- as.data.frame(marginaleffects::avg_slopes(fit, newdata = d,
    type = "probs", conf_level = 0.95, vcov = TRUE))
  if (any(!is.finite(as.matrix(ame[c("estimate", "std.error", "conf.low", "conf.high")]))))
    stop("Non-finite AME estimates or uncertainty.")
  sums <- stats::aggregate(estimate ~ term + contrast, data = ame, FUN = sum)
  if (max(abs(sums$estimate)) > 1e-6) stop("AMEs do not sum to zero across classes.")
  list(model = fit, ame = ame, n = nrow(d), omitted = sum(!keep))
}

significance <- function(p) ifelse(p < .001, "***", ifelse(p < .01, "**",
  ifelse(p < .05, "*", ifelse(p < .1, ".", ""))))

compare_reference_table <- function(ame, reference, destination) {
  if (!file.exists(reference)) return(invisible(NULL))
  old <- openxlsx::read.xlsx(reference, startRow=2, check.names=FALSE, sep.names=" ")
  term_map <- c("Age"="age", "Education x Major"="edu_major_f",
    "Authoritarian Tendency"="Factor1_Authoritarian", "Anti-Science/Expert Distrust"="Factor2_AntiScience",
    "Acceptance of Inequality"="Factor3_Inequality", "Log HH Income"="finc_log",
    "Gender"="gender", "Employment"="job4")
  if (!all(c("Variable","Contrast",class_names) %in% names(old))) {
    warning("Reference Table1.xlsx has an unexpected layout; comparison skipped.")
    return(invisible(NULL))
  }
  old <- old[old$Variable %in% names(term_map),]
  result <- dplyr::bind_rows(lapply(class_names,function(cl) {
    z <- ame[as.character(ame$group)==cl,]
    ix <- match(paste(term_map[old$Variable],old$Contrast),paste(z$term,z$contrast))
    ref <- as.character(old[[cl]])
    data.frame(Variable=old$Variable,Contrast=old$Contrast,Class=cl,
      reference_estimate=as.numeric(sub(" .*","",ref)),estimate=z$estimate[ix],
      reference_symbol=ifelse(grepl(" ",ref,fixed=TRUE),trimws(sub("^[^ ]+ *","",ref)),""),
      new_symbol=significance(z$p.value[ix]),stringsAsFactors=FALSE)
  }))
  result$match_3_decimals <- round(result$estimate,3)==result$reference_estimate
  utils::write.csv(result,destination,row.names=FALSE)
  message("Reference estimates reproduced: ",sum(result$match_3_decimals,na.rm=TRUE)," / ",nrow(result))
  invisible(result)
}

table_rows <- function(ame) {
  term_order <- c("age", "edu_major_f", "Factor1_Authoritarian", "Factor2_AntiScience",
                   "Factor3_Inequality", "finc_log", "gender", "job4")
  a <- ame[order(match(ame$term, term_order)), ]
  keys <- unique(a[c("term", "contrast")])
  contrast_order <- c("dY/dX", "Vocational/JC - Mid/High School", "BA Humanities - Mid/High School",
    "BA Sciences - Mid/High School", "BA Other - Mid/High School", "Graduate - Mid/High School",
    "Female - Male", "Non-regular - Regular", "Self-employed - Regular", "Unemployed - Regular")
  keys <- keys[order(match(keys$term,term_order),match(keys$contrast,contrast_order)),]
  labels <- c(age = "Age", edu_major_f = "Education x Major",
    Factor1_Authoritarian = "Authoritarian tendency", Factor2_AntiScience = "Anti-science / expert distrust",
    Factor3_Inequality = "Acceptance of inequality", finc_log = "Log household income",
    gender = "Gender", job4 = "Employment")
  keys$Variable <- unname(labels[keys$term])
  keys$Unit <- keys$contrast
  keys$Unit[keys$term == "age"] <- "Per year"
  keys$Unit[keys$term == "finc_log"] <- "Per log10 income unit"
  keys$Unit[startsWith(keys$term, "Factor")] <- "Per factor-score unit"
  list(keys = keys, labels = labels)
}

clean_empty_drawing_relationships <- function(path) {
  # openxlsx 4.2.8 emits relationships to nonexistent empty drawings.
  # Remove only dangling drawing relationships for standards-compliant readers.
  temp <- tempfile("xlsx_validation_")
  dir.create(temp)
  on.exit(unlink(temp,recursive=TRUE),add=TRUE)
  utils::unzip(path,exdir=temp)
  changed <- FALSE
  rels <- list.files(temp,pattern="[.]rels$",recursive=TRUE,full.names=TRUE,all.files=TRUE)
  for (r in rels) {
    doc <- xml2::read_xml(r)
    nodes <- xml2::xml_find_all(doc,"//*[local-name()='Relationship']")
    for (node in nodes) {
      target <- xml2::xml_attr(node,"Target")
      kind <- xml2::xml_attr(node,"Type")
      if (grepl("/(drawing|vmlDrawing)$",kind) &&
          !file.exists(file.path(dirname(dirname(r)),target))) {
        xml2::xml_remove(node)
        changed <- TRUE
      }
    }
    xml2::write_xml(doc,r)
  }
  if (changed) zip::zipr(normalizePath(path),files=list.files(temp,recursive=TRUE,all.files=TRUE),root=temp,include_directories=FALSE,mode="mirror")
}

write_workbook <- function(reg, x, fa, path) {
  a <- reg$ame
  meta <- table_rows(a)
  keys <- meta$keys
  wb <- openxlsx::createWorkbook(creator = "PUS analysis")
  for (s in c("Table1", "Estimates", "Definitions")) openxlsx::addWorksheet(wb, s, gridLines = FALSE)
  openxlsx::modifyBaseFont(wb, fontSize = 11, fontName = "Arial")
  heading <- openxlsx::createStyle(fontColour = "#FFFFFF", fgFill = "#30445A", textDecoration = "bold",
    halign = "center", valign = "center", wrapText = TRUE)
  body <- openxlsx::createStyle(valign = "center", wrapText = TRUE)
  title <- openxlsx::createStyle(fontSize = 15, textDecoration = "bold")
  openxlsx::writeData(wb, "Table1", "Table 1. Average marginal effects on class membership", startRow = 2)
  openxlsx::addStyle(wb, "Table1", title, rows = 2, cols = 1)
  openxlsx::writeData(wb, "Table1", paste0("N = ", reg$n, ". AME above; standard error (SE) below. Probability units."), startRow = 3)
  openxlsx::writeData(wb, "Table1", t(c("Variable", "Contrast / unit", class_names)), startRow = 5, colNames = FALSE)
  openxlsx::addStyle(wb, "Table1", heading, rows = 5, cols = 1:7, gridExpand = TRUE)
  for (i in seq_len(nrow(keys))) {
    r <- 6 + (i - 1) * 2
    z <- a[a$term == keys$term[i] & a$contrast == keys$contrast[i], ]
    z <- z[match(class_names, as.character(z$group)), ]
    stopifnot(nrow(z) == 5, !anyNA(z$estimate))
    openxlsx::writeData(wb, "Table1", t(c(keys$Variable[i], keys$Unit[i])), startRow = r, colNames = FALSE)
    openxlsx::writeData(wb, "Table1", "SE", startRow = r+1, startCol = 2, colNames = FALSE)
    openxlsx::writeData(wb, "Table1", t(z$estimate), startRow = r, startCol = 3, colNames = FALSE)
    openxlsx::writeData(wb, "Table1", t(z$std.error), startRow = r+1, startCol = 3, colNames = FALSE)
    for (j in 1:5) {
      fmt <- if (keys$term[i] == "age") "0.0000" else "0.000"
      star <- significance(z$p.value[j])
      if (nzchar(star)) fmt <- paste0(fmt, '" ', star, '"')
      openxlsx::addStyle(wb, "Table1", openxlsx::createStyle(numFmt = fmt, halign = "right", valign = "center"), rows=r, cols=j+2)
    }
    openxlsx::addStyle(wb, "Table1", openxlsx::createStyle(numFmt='"("0.0000")"', halign="right", fontColour="#526171"), rows=r+1, cols=3:7, gridExpand=TRUE)
    openxlsx::addStyle(wb, "Table1", body, rows=r:(r+1), cols=1:2, gridExpand=TRUE)
  }
  end <- 5 + nrow(keys)*2
  notes <- c("AME = average marginal effect. SE = standard error. CI = confidence interval. Full estimates and 95% CIs are on Estimates.",
    "*** p < .001, ** p < .01, * p < .05, . p < .10. Two-sided normal tests. Estimates x 100 are percentage points.",
    "Categorical effects are discrete changes from the stated reference, averaged over the regression sample. Continuous effects are average derivatives.",
    "Income is log10 of household annual income in JPY 10,000. A one-unit log10 difference corresponds to tenfold income; AMEs are local slopes.",
    "Factor scores use the original regression-score scale (not divided by their sample SD). BA Humanities includes social sciences. Full definitions are on Definitions.",
    "Model-based delta-method SEs treat assigned classes and factor scores as fixed. They do not propagate LCA classification or factor-estimation uncertainty.",
    paste0("LCA uses N = ", sum(!is.na(x$lca_class)), "; regression uses complete cases N = ",reg$n,". Class 1 is the logit reference; AMEs are reported for all five classes."))
  for (i in seq_along(notes)) {
    r <- end + 2 + i
    openxlsx::mergeCells(wb, "Table1", cols=1:7, rows=r)
    openxlsx::writeData(wb, "Table1", notes[i], startRow=r, colNames=FALSE)
    openxlsx::addStyle(wb, "Table1", body, rows=r, cols=1)
    openxlsx::setRowHeights(wb, "Table1", r, 31)
  }
  openxlsx::setColWidths(wb, "Table1", cols=1:7, widths=c(31,40,23,23,23,23,25))
  openxlsx::setRowHeights(wb, "Table1", rows=5, heights=42)
  openxlsx::setRowHeights(wb, "Table1", rows=6:end, heights=29)
  openxlsx::freezePane(wb, "Table1", firstActiveRow=6, firstActiveCol=3)
  openxlsx::pageSetup(wb, "Table1", orientation="landscape", paperSize=8, fitToWidth=1, fitToHeight=1)

  numeric <- a[c("term", "contrast", "group", "estimate", "std.error", "conf.low", "conf.high", "p.value")]
  numeric$significance <- significance(numeric$p.value)
  openxlsx::writeData(wb, "Estimates", numeric, headerStyle=heading, withFilter=TRUE)
  openxlsx::addStyle(wb, "Estimates", openxlsx::createStyle(numFmt="0.000000",halign="right"), rows=2:(nrow(numeric)+1),cols=4:8,gridExpand=TRUE)
  openxlsx::setColWidths(wb, "Estimates", 1:9, c(30,40,30,16,16,16,16,16,15))
  openxlsx::setRowHeights(wb, "Estimates", 1:(nrow(numeric)+1), 22)
  openxlsx::freezePane(wb, "Estimates", firstRow=TRUE)
  openxlsx::pageSetup(wb,"Estimates",orientation="landscape",paperSize=8,fitToWidth=1,fitToHeight=0,printTitleRows=1)

  definitions <- data.frame(Variable=c("Age", "Gender", "Education x Major", "Employment",
    "Household income", "Factor scores", "Factor-score SDs", "Scientificity", "Class assignment", "Abbreviations"),
    Definition=c("Q2 codes 1–52 + 17 = 18–69 years. Continuous AME per year.",
    "Q1: Female (2) versus Male (1). Code 3 is missing and excluded from regression.",
    "Q3 1–2: Mid/High School (reference); 3–5: Vocational/JC. Q3=6 and Q4 1–12: BA Humanities (including social sciences); Q4 13–27: BA Sciences (including engineering, agriculture, health); remaining Q4: BA Other. Q3=7: Graduate. Current enrollment is included by the questionnaire.",
    "Q5 1,6,11: Regular (reference); 2,3: Non-regular; 4,5: Self-employed; 7–10: Unemployed. The last label also includes students and homemakers (not employed). Code 11 retains the original reviewed coding.",
    "Q6 1–10 mapped to 100,250,350,450,550,650,750,900,1200,1400 (JPY 10,000), then log10. HH = household. Income representatives, not exact reported amounts.",
    "Q7 recoded as 8 minus response. Instructed blank item Q7_4 excluded. Three-factor minres EFA, varimax rotation, regression scores. MR1=authority; MR2=anti-science/expert distrust; MR3=inequality. Higher scores follow these orientations; Q7_8 has a negative MR3 loading.",
    paste(sprintf("%s: %.6f", c("Authority","Anti-science","Inequality"), vapply(x[c("Factor1_Authoritarian","Factor2_AntiScience","Factor3_Inequality")], stats::sd, numeric(1))),collapse="; "),
    "Q14: 1–2 Scientific; 3 Neither; 4–5 Not scientific; 6–7 Don't know (including never heard). Ten nominal four-category items. Figures 1 and 3 show observed proportions.",
    "Five-class solution retained from the manuscript; maximum-posterior assignment. Figure 3 is observed ratings within assigned classes, not estimated item-response probabilities.",
    "AME: average marginal effect; SE: standard error; CI: confidence interval; SD: standard deviation; LCA: latent class analysis; EFA: exploratory factor analysis; BA: bachelor's; JC: junior college; STEM: science, technology, engineering and mathematics; JPY: Japanese yen."))
  openxlsx::writeData(wb, "Definitions", definitions, headerStyle=heading)
  openxlsx::addStyle(wb,"Definitions",body,rows=2:11,cols=1:2,gridExpand=TRUE)
  openxlsx::setColWidths(wb,"Definitions",1:2,c(28,125))
  openxlsx::setRowHeights(wb,"Definitions",1,25)
  openxlsx::setRowHeights(wb,"Definitions",2:11,c(35,45,90,80,65,90,45,65,60,75))
  openxlsx::pageSetup(wb,"Definitions",orientation="landscape",paperSize=8,fitToWidth=1,fitToHeight=1)
  openxlsx::saveWorkbook(wb, path, overwrite=TRUE)
  clean_empty_drawing_relationships(path)
}

write_figures <- function(x, indices, directory) {
  dir.create(directory, recursive=TRUE, showWarnings=FALSE)
  theme <- ggplot2::theme_minimal() + ggplot2::theme(
    axis.text.x=ggplot2::element_text(angle=45,hjust=1,size=11,face="bold"),
    axis.text.y=ggplot2::element_text(size=10),
    axis.title=ggplot2::element_text(size=11,face="bold"),
    plot.title=ggplot2::element_text(size=14,hjust=.5,face="bold"),
    legend.title=ggplot2::element_text(size=11,face="bold"),
    legend.text=ggplot2::element_text(size=11),legend.position="bottom",
    panel.grid.major.x=ggplot2::element_blank(),panel.grid.minor=ggplot2::element_blank(),
    plot.margin=ggplot2::margin(10,10,10,10))
  long <- tidyr::pivot_longer(x[c("lca_class", field_vars)], dplyr::all_of(field_vars), names_to="field", values_to="rating")
  long$field <- factor(long$field,levels=field_vars,labels=field_names)
  fig1 <- ggplot2::ggplot(long,ggplot2::aes(x=field,fill=rating)) +
    ggplot2::geom_bar(position="fill") + ggplot2::scale_fill_manual(values=rating_colors) +
    ggplot2::scale_y_continuous(labels=scales::percent_format()) +
    ggplot2::labs(title="Scientificity Rating Distribution by Discipline",x="Discipline",y="Proportion",fill="Rating") + theme
  fi <- tidyr::pivot_longer(indices[c("Classes","AIC","BIC","Gsq")],-Classes,names_to="variable",values_to="value")
  fig2 <- ggplot2::ggplot(fi,ggplot2::aes(x=Classes,y=value,color=variable)) +
    ggplot2::geom_line() + ggplot2::geom_point() + ggplot2::theme_minimal() +
    ggplot2::labs(title="Fit indices for LCA",x="The number of classes",y="Value")
  profiles <- long[!is.na(long$lca_class), ] |>
    dplyr::count(lca_class,field,rating,.drop=FALSE) |>
    dplyr::group_by(lca_class,field) |>
    dplyr::mutate(proportion=n/sum(n)) |> dplyr::ungroup()
  panels <- lapply(class_names,function(cl) {
    z <- profiles[profiles$lca_class==cl,]
    z$field <- factor(as.character(z$field), levels=sort(field_names))
    ggplot2::ggplot(z,ggplot2::aes(x=field,y=proportion,fill=rating)) +
      ggplot2::geom_col(width=.8) + ggplot2::scale_fill_manual(values=rating_colors) +
      ggplot2::scale_y_continuous(labels=scales::percent_format()) +
      ggplot2::labs(title=cl,subtitle="Scientificity Rating Distribution by Discipline",x="Discipline",y="Proportion",fill="Rating") + theme +
      ggplot2::theme(legend.title=ggplot2::element_text(size=10),legend.text=ggplot2::element_text(size=10),
        plot.subtitle=ggplot2::element_text(size=10,hjust=.5),plot.margin=ggplot2::margin(8,8,8,8)) +
      ggplot2::guides(fill=ggplot2::guide_legend(nrow=1,byrow=TRUE))
  })
  fig3 <- patchwork::wrap_plots(panels,ncol=3,nrow=2) + patchwork::plot_annotation(
    title="Scientificity Rating Distribution by Latent Class and Discipline",
    theme=ggplot2::theme(plot.title=ggplot2::element_text(size=15,face="bold",hjust=.5)))
  plots <- list(Figure1=fig1,Figure2=fig2,Figure3=fig3)
  sizes <- list(c(9.33,6.67),c(8,4.85),c(24,14))
  for (i in seq_along(plots)) {
    stem <- file.path(directory,names(plots)[i])
    ggplot2::ggsave(paste0(stem,".png"),plots[[i]],width=sizes[[i]][1],height=sizes[[i]][2],dpi=300,device=ragg::agg_png,bg="white")
    ggplot2::ggsave(paste0(stem,".pdf"),plots[[i]],width=sizes[[i]][1],height=sizes[[i]][2],device=grDevices::cairo_pdf,bg="white")
  }
  utils::write.csv(profiles,file.path(directory,"Figure3_observed_proportions.csv"),row.names=FALSE)
  distribution <- long |> dplyr::count(field,rating,.drop=FALSE) |>
    dplyr::group_by(field) |> dplyr::mutate(proportion=n/sum(n)) |> dplyr::ungroup()
  utils::write.csv(distribution,file.path(directory,"Figure1_observed_proportions.csv"),row.names=FALSE)
}

run_final_analysis <- function(project_root = find_project_root(),
                               output_dir = file.path(project_root, "output"),
                               input_file = NULL, encoding = "auto") {
  check_packages()
  project_root <- normalizePath(project_root,mustWork=TRUE)
  survey <- read_survey(project_root, input_file, encoding)
  input <- survey$file
  raw <- survey$data
  fa <- add_factor_scores(prepare_data(raw))
  lca <- fit_lca(fa$data)
  reg <- fit_regression(lca$data)
  dir.create(output_dir,recursive=TRUE,showWarnings=FALSE)
  figures <- file.path(output_dir,"final_figures")
  diagnostics <- file.path(output_dir,"final_diagnostics")
  dir.create(diagnostics,recursive=TRUE,showWarnings=FALSE)
  write_workbook(reg,lca$data,fa$fa,file.path(output_dir,"Table1_final.xlsx"))
  write_figures(lca$data,lca$indices,figures)
  utils::write.csv(lca$indices,file.path(diagnostics,"LCA_fit_indices.csv"),row.names=FALSE)
  utils::write.csv(lca$original,file.path(diagnostics,"LCA_original_1000_iterations.csv"),row.names=FALSE)
  counts <- as.data.frame(table(lca$data$lca_class)); names(counts)<-c("Class","N")
  utils::write.csv(counts,file.path(diagnostics,"class_counts.csv"),row.names=FALSE)
  utils::write.csv(unclass(fa$fa$loadings),file.path(diagnostics,"factor_loadings.csv"))
  probs <- dplyr::bind_rows(lapply(seq_along(field_vars),function(i) {
    z <- as.data.frame(lca$models[["5"]]$probs[[i]])
    names(z)<-rating_names; data.frame(Class=class_names,Field=field_names[i],z,check.names=FALSE)
  }))
  utils::write.csv(probs,file.path(diagnostics,"LCA_conditional_probabilities.csv"),row.names=FALSE)
  compare_reference_table(reg$ame,file.path(project_root,"output","Table1.xlsx"),
    file.path(diagnostics,"Table1_reference_comparison.csv"))
  info <- c(paste("Input:",basename(input)),paste("Input encoding:", survey$encoding),
    paste("Input MD5:",unname(tools::md5sum(input))),
    paste("Survey N:",nrow(raw)),paste("LCA N:",sum(counts$N)),paste("Regression N:",reg$n),
    paste("Regression omitted:",reg$omitted),paste("Missing gender:",sum(is.na(lca$data$gender))),
    paste("Multinom convergence:",reg$model$convergence),
    "LCA: seed=123; 2:8 sequentially; nrep=10; maxiter=1000; capped best solution continued to maxiter=10000.",
    "Five classes retained as in the manuscript. Inspect all fit indices; selection is not an automatic BIC minimum.",
    "SE/CI: model-based delta method, classes and factor scores treated as fixed.",
    "Method reference: https://marginaleffects.com/man/r/slopes.html",
    vapply(required_packages,function(p)paste(p,as.character(utils::packageVersion(p))),character(1)),
    capture.output(utils::sessionInfo()))
  writeLines(info,file.path(diagnostics,"run_information.txt"))
  message("Saved Table 1 and Figures 1–3 to: ", normalizePath(output_dir))
  invisible(list(lca=lca,regression=reg,factor=fa$fa))
}

run_final_cli <- function(args = character(), project_root = find_project_root()) {
  value <- function(flag) {
    x <- args[startsWith(args,paste0(flag,"="))]
    if(length(x)>1) stop("Duplicate option: ",flag)
    if(length(x)) substring(x,nchar(flag)+2) else NULL
  }
  if(any(!grepl("^--(project-root|output-dir|input|encoding)=",args)))
    stop("Options: --project-root=PATH, --output-dir=PATH, --input=PATH, --encoding=auto|UTF-8-BOM|CP932")
  root <- value("--project-root")
  if(is.null(root)) root <- project_root
  out <- value("--output-dir")
  if(is.null(out)) out <- file.path(root,"output")
  enc <- value("--encoding")
  if(is.null(enc)) enc <- "auto"
  run_final_analysis(root, out, input_file = value("--input"), encoding = enc)
}

if (sys.nframe() == 0L) {
  self <- sub("^--file=", "", commandArgs()[startsWith(commandArgs(), "--file=")])
  start <- if (length(self) == 1L) dirname(normalizePath(self, mustWork = TRUE)) else getwd()
  run_final_cli(commandArgs(trailingOnly = TRUE), project_root = find_project_root(start))
}
