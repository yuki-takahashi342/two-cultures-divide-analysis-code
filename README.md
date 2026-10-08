# Public perceptions of academic disciplines in Japan

R code to reproduce manuscript Table 1 and Figures 1–3, plus the supplemental analyses. Respondent-level data are private and are not included in Git. The existing folder layout is retained.

## Quick start in RStudio

1.  Open `PUS_repository.Rproj`.
2.  Place the authorized survey CSV at `data/data.csv` (already present in the local working copy).
3.  Install the required packages once if needed:

``` r
source("R_scripts/Final_use_script.R")
install.packages(required_packages)
```

4.  Run the manuscript analysis:

``` r
source("run_analysis.R")
```

This runs the full workflow in a fresh R session: read the data, construct variables, estimate factors and latent classes, fit the regression, and export all manuscript figures and the table. It does not rely on objects in the Global Environment. Sourcing `R_scripts/Final_use_script.R` alone defines functions; to run those directly use `run_final_analysis()`.

## Command line

From the project directory:

``` sh
Rscript run_analysis.R
```

From another directory:

``` sh
Rscript /path/to/PUS_repository/run_analysis.R
```

Optional input and output settings:

``` sh
Rscript run_analysis.R --input="/path/to/private-survey.csv" --output-dir="/path/to/output" --encoding=auto
```

`--project-root=PATH` selects a different data/output root. Explicit relative input/output paths are resolved against the current working directory. Default paths are resolved against the project root. The reader tries UTF-8 first, then CP932, and checks the required question columns. The current `data/data.csv` is UTF-8; the original delivered survey was CP932. If `data/data.csv` is absent, the reader accepts one original file ending in `241010.csv` in `data/`. The supplied CSV must retain the original Q1–Q6, substantive Q7, and Q14 question headers and response codes. Topic-model columns are not required.

## Manuscript outputs

| Item | File |
|------------------------------------|------------------------------------|
| Table 1: average marginal effects with SEs | `output/Table1_final.xlsx` |
| Full estimates, 95% CIs, p values and definitions | `Estimates` and `Definitions` sheets in the same workbook |
| Figure 1: observed scientificity distributions | `output/final_figures/Figure1.png` and `.pdf` |
| Figure 2: LCA fit indices, 2–8 classes | `output/final_figures/Figure2.png` and `.pdf` |
| Figure 3: observed distributions within assigned classes | `output/final_figures/Figure3.png` and `.pdf` |
| Figure source summaries | `output/final_figures/*_observed_proportions.csv` |
| Fit indices, factor loadings, class counts and software versions | `output/final_diagnostics/` |

Figure 3 displays observed proportions within assigned classes. Supplemental Figure S1 displays model-estimated conditional response probabilities. Five classes are retained to match the manuscript; the code does not choose a class count automatically. The analysis uses no sampling weights and no extra Q7 item 4 screening. Model-based regression uncertainty treats factor scores and class assignments as fixed.

## Supplemental outputs

``` sh
Rscript PUS_Supplemental_Code/Supplemental_use_script.R
Rscript PUS_Supplemental_Code/Plot_supplement.R output/supplemental
```

The tables are written to `output/supplemental/`; the second command creates `Figure_S1.png` there. The 100-start optimization check can take several minutes. RStudio can run the tables with `source("PUS_Supplemental_Code/Supplemental_use_script.R")`. The supplemental functions share the canonical implementation in `R_scripts/Final_use_script.R`; the older same-named file in `PUS_Supplemental_Code/` forwards to it.

## Git and reproducibility

`.gitignore` excludes `data/`, RStudio session files, R history/workspaces, and generated output directories. The scripts do not export respondent-level data. GitHub publication is separate from local execution; no upload is performed by these scripts.

The complete workflow was verified with 1,017 survey records and 1,002 regression cases. All 70 AMEs, SEs, confidence intervals and p values matched the previously verified supplemental results. Tested package versions are recorded in the output diagnostic file. Required packages are checked, not automatically installed or attached. Run the input/path smoke checks without private data using:

``` sh
Rscript tests/smoke_input.R
```
