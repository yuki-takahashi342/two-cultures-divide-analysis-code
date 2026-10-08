# Recreate Figure S1 from the aggregate conditional-probability export.
# Usage: Rscript Plot_supplement.R results
args <- commandArgs(trailingOnly = TRUE)
out <- if (length(args)) args[1] else "results"
library(ggplot2)
library(tidyr)
z <- read.csv(file.path(out, "conditional_response_probabilities.csv"))
z$class <- factor(z$class, levels = 1:5,
  labels = c("1  Don’t Know", "2  Neutral", "3  Low Rating", "4  High Rating", "5  STEM High Rating"))
z$field <- factor(z$field, levels = rev(unique(z$field)))
z <- pivot_longer(z, Dont_know:Scientific, names_to = "rating", values_to = "probability")
z$rating <- factor(z$rating,
  levels = c("Dont_know", "Not_scientific", "Neither", "Scientific"),
  labels = c("Don’t\nknow", "Not\nscientific", "Neither", "Scientific"))
g <- ggplot(z, aes(rating, field, fill = probability)) +
  geom_tile(color = "white", linewidth = .35) +
  geom_text(aes(label = sprintf("%.2f", probability),
                color = probability > .55), size = 2.7) +
  scale_color_manual(values = c("FALSE" = "#222222", "TRUE" = "white"), guide = "none") +
  scale_fill_gradient(low = "#f4f8fc", high = "#174f80", limits = c(0, 1), guide = "none") +
  facet_wrap(~class, ncol = 2) +
  labs(x = NULL, y = NULL) +
  theme_minimal(base_size = 10) +
  theme(panel.grid = element_blank(), axis.text.x = element_text(size = 8),
        axis.text.y = element_text(size = 8.5), strip.text = element_text(face = "bold"),
        panel.spacing = grid::unit(8, "mm"))
ggsave(file.path(out, "Figure_S1.png"), g, width = 6.55, height = 8.05,
       units = "in", dpi = 300, device = ragg::agg_png)
