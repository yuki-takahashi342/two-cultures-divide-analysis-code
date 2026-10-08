# Input/entry-point regression checks. Only synthetic data are used.
self <- sub("^--file=", "", commandArgs()[startsWith(commandArgs(), "--file=")])
root <- dirname(dirname(normalizePath(self, mustWork = TRUE)))
e <- new.env(parent = globalenv())
sys.source(file.path(root, "R_scripts", "Final_use_script.R"), envir = e)
stopifnot(!exists("dat", envir = e, inherits = FALSE),
          !exists("data_with_scores", envir = e, inherits = FALSE))

local({
  tmp <- tempfile("PUS input with spaces ")
  dir.create(file.path(tmp, "data"), recursive = TRUE)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  headers <- c(paste0("Q", 1:6, ".質問"), paste0("Q7項目", setdiff(1:10, 4), ".質問"),
               paste0("Q14項目", 1:10, ".分野"))
  synthetic <- as.data.frame(matrix(1L, 2L, length(headers)))
  names(synthetic) <- headers
  input <- file.path(tmp, "data", "data.csv")
  utils::write.csv(synthetic, input, row.names = FALSE, fileEncoding = "UTF-8")
  utf8 <- e$read_survey(tmp)
  stopifnot(utf8$encoding == "UTF-8-BOM", nrow(utf8$data) == 2L)
  utils::write.csv(synthetic, input, row.names = FALSE, fileEncoding = "CP932")
  cp932 <- e$read_survey(tmp)
  stopifnot(cp932$encoding == "CP932", identical(utf8$data, cp932$data))
  moved <- file.path(tmp, "survey241010.csv")
  file.rename(input, moved)
  explicit <- e$read_survey(tmp, input_file = moved)
  stopifnot(identical(cp932$data, explicit$data))
  file.rename(moved, file.path(tmp, "data", basename(moved)))
  stopifnot(identical(cp932$data, e$read_survey(tmp)$data))
  utils::write.csv(synthetic[-1], input, row.names = FALSE, fileEncoding = "UTF-8")
  error <- tryCatch(e$read_survey(tmp), error = conditionMessage)
  stopifnot(is.character(error), grepl("Q1.", error, fixed = TRUE))
})

# Test CLI dispatch without fitting models or requiring private data.
e$run_final_analysis <- function(...) list(...)
args <- e$run_final_cli(character(), project_root = root)
stopifnot(identical(args[[1]], root), identical(args[[2]], file.path(root, "output")),
          identical(args$encoding, "auto"))
args <- e$run_final_cli(c("--project-root=/test", "--input=private.csv", "--encoding=CP932"))
stopifnot(args[[1]] == "/test", args$input_file == "private.csv", args$encoding == "CP932")
duplicate <- tryCatch(e$run_final_cli(c("--input=a", "--input=b"), project_root = root),
                      error = conditionMessage)
stopifnot(is.character(duplicate), grepl("Duplicate option", duplicate))
stopifnot(identical(e$find_project_root(file.path(root, "R_scripts")), root))

# A sourced legacy path must expose the canonical functions without running them.
f <- new.env(parent = globalenv())
source(file.path(root, "PUS_Supplemental_Code", "Final_use_script.R"), local = f)
stopifnot(exists("read_survey", envir = f, inherits = FALSE),
          exists("run_final_analysis", envir = f, inherits = FALSE))
cat("PASS: UTF-8/CP932, explicit/default input, invalid headers, CLI paths and source-only entry points.\n")
