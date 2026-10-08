# One entry point for manuscript Table 1 and Figures 1–3.
# RStudio: open PUS_repository.Rproj, then source("run_analysis.R").
# Terminal: Rscript /path/to/PUS_repository/run_analysis.R
local({
  frames <- sys.frames()
  files <- unlist(lapply(frames, function(x) x$ofile), use.names = FALSE)
  if (length(files)) {
    self <- tail(files, 1L)
    args <- character()
  } else {
    files <- sub("^--file=", "", commandArgs()[startsWith(commandArgs(), "--file=")])
    self <- if (length(files) == 1L) files else "run_analysis.R"
    args <- if (interactive()) character() else commandArgs(trailingOnly = TRUE)
  }
  root <- dirname(normalizePath(self, mustWork = TRUE))
  source(file.path(root, "R_scripts", "Final_use_script.R"), local = TRUE)
  run_final_cli(args, project_root = root)
})
