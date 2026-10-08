# Compatibility entry point. The canonical implementation lives in ../R_scripts.
local({
  files <- unlist(lapply(sys.frames(), function(x) x$ofile), use.names = FALSE)
  sourced <- length(files) > 0L
  self <- if (sourced) tail(files, 1L) else
    sub("^--file=", "", commandArgs()[startsWith(commandArgs(), "--file=")])
  if (length(self) != 1L) stop("Use Rscript or source() to load this file.")
  root <- dirname(dirname(normalizePath(self, mustWork = TRUE)))
  target <- parent.env(environment())
  sys.source(file.path(root, "R_scripts", "Final_use_script.R"), envir = target)
  if (!sourced) get("run_final_cli", envir = target)(commandArgs(trailingOnly = TRUE), project_root = root)
})
