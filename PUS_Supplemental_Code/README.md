# Supplemental analysis files

## Contents

- `Final_use_script.R`: compatibility entry point forwarding to `../R_scripts/Final_use_script.R`.
- `Supplemental_use_script.R`: sample summaries, factor loadings, latent class diagnostics, all multinomial coefficients and average marginal effects, and the additional 100-start optimization check.
- `Plot_supplement.R`: generate Figure S1 (parallel-analysis scree plot) from the private Q7 data and Figure S2 from aggregate conditional response probabilities.
- `results/`: aggregate CSV outputs, Figures S1 and S2, software citations, and computational environment. No respondent-level records are included.

## Run

Run from the repository root with the private survey in `data/data.csv`. The input reader detects UTF-8 or CP932 and shares the main functions in `R_scripts/Final_use_script.R`.

```sh
Rscript PUS_Supplemental_Code/Supplemental_use_script.R
Rscript PUS_Supplemental_Code/Plot_supplement.R output/supplemental
```

The default output is `output/supplemental/`. The table script also produces Figures S1 and S2 as PNG and PDF. The second command is optional and redraws only the figures. Optional `--project-root=PATH`, `--output-dir=PATH`, `--input=PATH`, and `--encoding=auto|UTF-8-BOM|CP932` settings are supported by the table script. The plotting script takes its results directory as its first positional argument. To recreate all manuscript tables and figures, run `Rscript run_analysis.R` from the repository root. See `../README.md` for RStudio instructions.

R packages are listed in `Final_use_script.R`; the plot additionally uses ggplot2, tidyr and ragg. Installed versions used for this run appear in `results/run_information.txt`. The scripts write files to the specified output directories and do not alter the source data. The 100-start check can take several minutes. Class numbers can change across optimization runs; the check explicitly aligns its labels to the main solution.

## Table mapping

| Supplemental item | Result file |
|---|---|
| S1 sample flow | S1_sample_flow.csv |
| S2 descriptive statistics | S2_categorical.csv; S2_continuous.csv |
| S2b original scientificity responses | S2b_Q14_original_categories.csv |
| S3 factor loadings | S3_factor_loadings.csv |
| S4 factor scores | S4_factor_scores.csv |
| S5 model comparison | S5_fit_indices.csv |
| S6 classification quality | S6_class_quality.csv; classification_summary.csv |
| Figure S1: scree plot | Figure_S1.png; Figure_S1.pdf; Figure_S1_eigenvalues.csv; Figure_S1_settings.txt |
| Figure S2: conditional response probabilities | conditional_response_probabilities.csv; Figure_S2.png; Figure_S2.pdf |
| S7 regression coefficients | S7_multinomial_coefficients.csv |
| S8 average marginal effects | S8_average_marginal_effects.csv |
| S9 optimization check | S9_optimization.csv; S9_optimization_summary.csv; S9_AME_optimization_comparison.csv |

The Word document contains these results and the questionnaire/coding descriptions. The analysis scripts generate numerical outputs; they do not automatically update the Word file.

## Reproduced results

- Factor analysis and latent class analysis: N = 1,017.
- Complete-case regression: N = 1,002 (15 gender nonresponses omitted).
- All 60 multinomial coefficients and 70 average marginal effects, with SEs and 95% confidence intervals, were checked against the displayed Word tables.
- Additional five-class fit: seed 456, 100 starts, maximum 10,000 iterations. After label alignment, all 1,017 assignments and all 70 AMEs agree with the main result.
- The five-class choice follows the manuscript. BIC is lowest at seven classes; AIC is lowest at eight. The additional check concerns optimization within five classes, not selection of the class count.
- Regression SEs do not propagate uncertainty in estimated factor scores or assigned latent classes.

## Author confirmations remaining in Word

Nine yellow prompts cover fieldwork dates; provider, recruitment, quotas and incentives; invitations, response rate and provider checks; the instructed nonresponse item; information-module implementation; consent; Q7 item sources and factor rationale; data/code access; and references to add.

The delivered records and data map indicate 7–9 October 2024, whereas the manuscript/questionnaire plan refers to September. Confirm the actual fieldwork dates before harmonizing the documents.

The final code does not use Q7 item 4 to exclude cases. Its delivered values are 0 for 151 records and 1–7 for 866 records. Confirm the code meaning and intended screening procedure; no new exclusion rule has been imposed.

Figure S1 uses the nine substantive Q7 items (item 4 excluded), `psych::fa.parallel(fa="fa", fm="minres", nfactors=1, n.iter=20, use="complete.obs", SMC=FALSE, sim=TRUE, quant=.95)`, seed 123 and one process. The displayed simulation/resampling curves are means. The seed is fixed for reproducibility and the caller RNG state is restored. `nfactors=1` is the default eigenvalue reduction for this diagnostic; it does not replace the three-factor EFA model. The source image did not record its seed, so the null curves may differ slightly.
