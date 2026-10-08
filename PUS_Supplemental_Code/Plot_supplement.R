# Supplemental Figure S1 (parallel-analysis scree plot) and Figure S2 (LCA profiles).
# CLI: Rscript PUS_Supplemental_Code/Plot_supplement.R output/supplemental
# Optional flags: --project-root=PATH --input=PATH --encoding=auto
# Sourcing this file defines functions only; the supplemental analysis calls them.

parallel_scree <- function(data, seed = 123L, n_iter = 20L, plot = FALSE) {
  items <- paste0("q7_", setdiff(1:10, 4))
  if (!all(items %in% names(data)) || anyNA(data[items]))
    stop("Figure S1 requires complete data on the nine substantive Q7 items.")
  # Preserve the caller's RNG state and use one process for deterministic resampling.
  old_kind <- RNGkind()
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) old_seed <- get(".Random.seed", envir = .GlobalEnv)
  old_options <- options(mc.cores = 1L)
  on.exit({
    options(old_options)
    do.call(RNGkind, as.list(old_kind))
    if (had_seed) assign(".Random.seed", old_seed, envir = .GlobalEnv) else
      if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
        rm(".Random.seed", envir = .GlobalEnv)
  }, add = TRUE)
  RNGkind("Mersenne-Twister", "Inversion", "Rejection")
  set.seed(seed)
  pa <- psych::fa.parallel(data[items], fa = "fa", fm = "minres", nfactors = 1,
    n.iter = n_iter, use = "complete.obs", cor = "cor", SMC = FALSE,
    sim = TRUE, quant = .95, plot = plot)
  # These are the three displayed curves from fa.parallel (null-curve means).
  values <- data.frame(factor_number = seq_along(items), actual = pa$fa.values,
    simulated_mean = pa$fa.sim, resampled_mean = pa$fa.simr,
    component_eigenvalue = pa$pc.values)
  stopifnot(all(is.finite(as.matrix(values))))
  list(values = values, seed = seed, n_iter = n_iter, n = nrow(data),
       recommended_factors = pa$nfact)
}

write_scree_figure <- function(data, out) {
  save_plot <- function(path, device) {
    if (device == "png") ragg::agg_png(path, width = 8, height = 4.85, units = "in", res = 300)
    else grDevices::cairo_pdf(path, width = 8, height = 4.85)
    on.exit(grDevices::dev.off(), add = TRUE)
    # Match the manuscript's fa.parallel(..., fa="fa", use="complete.obs")
    # followed by abline(h=0), including psych's standard plotting defaults.
    result <- parallel_scree(data, plot = TRUE)
    graphics::abline(h = 0)
    result
  }
  result <- save_plot(file.path(out, "Figure_S1.png"), "png")
  pdf_result <- save_plot(file.path(out, "Figure_S1.pdf"), "pdf")
  stopifnot(identical(result$values, pdf_result$values))
  z <- result$values
  utils::write.csv(z, file.path(out, "Figure_S1_eigenvalues.csv"), row.names = FALSE)
  writeLines(c(
    "Figure S1: parallel-analysis scree plot for nine substantive Q7 items; Q7_4 excluded.",
    paste("N:", result$n), paste("Seed:", result$seed), paste("Iterations:", result$n_iter),
    "psych::fa.parallel: fa='fa', fm='minres', nfactors=1, SMC=FALSE, use='complete.obs', cor='cor', sim=TRUE, quant=.95.",
    "nfactors=1 is the default reduction used to calculate the scree eigenvalues; the retained EFA still has three factors.",
    "Displayed null curves are means, matching fa.parallel; its reported factor recommendation is recorded separately below.",
    paste("fa.parallel recommended factors:", result$recommended_factors),
    "component_eigenvalue in the CSV is the ordinary correlation-matrix eigenvalue, not the plotted factor eigenvalue.",
    "The figure diagnoses factor retention; it does not change the three-factor manuscript model.",
    paste("psych version:", utils::packageVersion("psych"))),
    file.path(out, "Figure_S1_settings.txt"))
  invisible(result)
}

write_supplement_figures <- function(out, data) {
  required <- c("psych", "ggplot2", "tidyr", "ragg")
  absent <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
  if (length(absent)) stop("Install missing packages: ", paste(absent, collapse = ", "))
  if (!file.exists(file.path(out, "conditional_response_probabilities.csv")))
    stop("Run Supplemental_use_script.R first to create conditional_response_probabilities.csv.")
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  result <- write_scree_figure(data, out)
  write_probability_figure(out)
  message("Saved Figures S1 and S2 (PNG/PDF) to: ", normalizePath(out))
  invisible(result)
}

write_probability_figure <- function(out) {
  z <- read.csv(file.path(out, "conditional_response_probabilities.csv"))
  z$class <- factor(z$class, levels = 1:5,
    labels = c("1  Don’t Know", "2  Neutral", "3  Low Rating", "4  High Rating", "5  STEM High Rating"))
  z$field <- factor(z$field, levels = rev(unique(z$field)))
  z <- tidyr::pivot_longer(z, Dont_know:Scientific, names_to = "rating", values_to = "probability")
  z$rating <- factor(z$rating,
    levels = c("Dont_know", "Not_scientific", "Neither", "Scientific"),
    labels = c("Don’t\nknow", "Not\nscientific", "Neither", "Scientific"))
  g <- ggplot2::ggplot(z, ggplot2::aes(rating, field, fill = probability)) +
    ggplot2::geom_tile(color = "white", linewidth = .35) +
    ggplot2::geom_text(ggplot2::aes(label = sprintf("%.2f", probability),
                  color = probability > .55), size = 2.7) +
    ggplot2::scale_color_manual(values = c("FALSE" = "#222222", "TRUE" = "white"), guide = "none") +
    ggplot2::scale_fill_gradient(low = "#f4f8fc", high = "#174f80", limits = c(0, 1), guide = "none") +
    ggplot2::facet_wrap(~class, ncol = 2) +
    ggplot2::labs(x = NULL, y = NULL) +
    ggplot2::theme_minimal(base_size = 10) +
    ggplot2::theme(panel.grid = ggplot2::element_blank(), axis.text.x = ggplot2::element_text(size = 8),
          axis.text.y = ggplot2::element_text(size = 8.5), strip.text = ggplot2::element_text(face = "bold"),
          panel.spacing = grid::unit(8, "mm"))
  ggplot2::ggsave(file.path(out, "Figure_S2.png"), g, width = 6.55, height = 8.05,
         units = "in", dpi = 300, device = ragg::agg_png)
  
  ggplot2::ggsave(file.path(out, "Figure_S2.pdf"), g, width = 6.55, height = 8.05,
    units = "in", device = grDevices::cairo_pdf)
}

if (sys.nframe() == 0L) {
  self <- sub("^--file=", "", commandArgs()[startsWith(commandArgs(), "--file=")])
  root <- dirname(dirname(normalizePath(self, mustWork = TRUE)))
  source(file.path(root, "R_scripts", "Final_use_script.R"))
  args <- commandArgs(trailingOnly = TRUE)
  positional <- args[!startsWith(args, "--")]
  flags <- args[startsWith(args, "--")]
  if (length(positional) > 1L || any(!grepl("^--(project-root|input|encoding)=", flags)))
    stop("Usage: Plot_supplement.R [OUTPUT_DIR] [--project-root=PATH] [--input=PATH] [--encoding=auto]")
  arg <- function(flag, default = NULL) {
    z <- flags[startsWith(flags, paste0(flag, "="))]
    if (length(z) > 1L) stop("Duplicate option: ", flag)
    if (length(z)) substring(z, nchar(flag) + 2L) else default
  }
  root <- arg("--project-root", root)
  out <- if (length(positional)) positional else file.path(root, "output", "supplemental")
  survey <- read_survey(root, arg("--input"), arg("--encoding", "auto"))
  write_supplement_figures(out, prepare_data(survey$data))
}
