library(dplyr)
library(ggplot2)
library(readr)

# Load the CSV file
file_path_park_no_park_pm <- "/Users/sebastianherbst/Dissertation/Data processing/R_results/Park_no_park_results/Park_v_stree_results_pm_cleaned.csv"
file_path_park_no_park_temp <- "/Users/sebastianherbst/Dissertation/Data processing/R_results/Park_no_park_results/Park_v_stree_results_temp_cleaned.csv"

df_pm <- read_csv(file_path_park_no_park_pm, na = c("", "NA"))
df_temp <- read_csv(file_path_park_no_park_temp, na = c("", "NA"))

# Filter the dataframe to get the mean differences and p-values for each pollutant
mean_diff_pm_df <- df_pm %>%
  filter(Statistic == "mean_difference") %>%
  select(Site_Date, PM1, PM2.5, PM4, PM10)
mean_diff_temp_df <- df_temp %>%
  filter(Statistic == "mean_difference") %>%
  select(Site_Date, Temperature)


p_value_pm_df <- df_pm %>%
  filter(Statistic == "p_value") %>%
  select(Site_Date, PM1, PM2.5, PM4, PM10)
p_value_temp_df <- df_temp %>%
  filter(Statistic == "p_value") %>%
  select(Site_Date, Temperature)

# Reshape the data for plotting
mean_diff_pm_long <- mean_diff_pm_df %>%
  pivot_longer(cols = PM1:PM10, names_to = "Pollutant", values_to = "mean_difference")
mean_diff_temp_long <-mean_diff_temp_df %>%
  pivot_longer(cols = Temperature, names_to = "Pollutant", values_to = "mean_difference")
  
p_value_pm_long <- p_value_pm_df %>%
  pivot_longer(cols = PM1:PM10, names_to = "Pollutant", values_to = "p_value")
p_value_temp_long <- p_value_temp_df %>%
  pivot_longer(cols = Temperature, names_to = "Pollutant", values_to = "p_value")

# Combine the mean difference and p-value data
plot_pm_data <- mean_diff_pm_long %>%
  left_join(p_value_pm_long, by = c("Site_Date", "Pollutant"))
plot_temp_data <- mean_diff_temp_long %>%
  left_join(p_value_temp_long, by = c("Site_Date", "Pollutant"))

# Create a plot
local_t_test_plot <- ggplot(plot_pm_data, aes(x = Pollutant, y = mean_difference, fill = p_value < 0.05)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.4), width = 0.3) +  # Bar plot for mean differences
  theme_minimal() +
  labs(title = "Mean difference of measurements between Streets and Parks",
       x = "Measurement",
       y = "Mean difference",
       fill = "Significance (p < 0.05)") +
  scale_fill_manual(values = c("TRUE" = "salmon", "FALSE" = "skyblue"))+
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 11))+
  theme(legend.position = "none",
        panel.spacing = unit(1, "lines"),
        strip.text = element_text(size = 11)) +
          facet_wrap(~ Site_Date, scales = "free_x", nrow = 1)

# Display the plot
print(local_t_test_plot)
#save
ggsave("/Users/sebastianherbst/Dissertation/Data processing/R_results/Park_no_park_results/mean_diff_pm_park_no_park.png", plot = local_t_test_plot, width = 12, height = 6)



# Create a plot
local_t_test_temp_plot <- ggplot(plot_temp_data, aes(x = Pollutant, y = mean_difference, fill = p_value < 0.05)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.4), width = 0.3) +  # Bar plot for mean differences
  theme_minimal() +
  labs(title = "Mean difference in Temperature between Streets and Parks",
       x = "Temperatures (in °C)",
       y = "Mean difference",
       fill = "Significant (p < 0.05)") +
  scale_fill_manual(values = c("TRUE"="salmon", "FALSE"="skyblue"))+
  theme(axis.text.x = element_blank(),
        legend.position = "none",
        strip.text = element_text(size = 11)) +
  facet_wrap(~ Site_Date, scales = "free_x", nrow = 1)

# Display the plot
print(local_t_test_temp_plot)

# # Save the plot
# plot_file <- "/path/to/save/t_test_plot_all_sites.png"  # Update the path as necessary
ggsave("/Users/sebastianherbst/Dissertation/Data processing/R_results/Park_no_park_results/mean_diff_temp_park_no_park.png", plot = local_t_test_temp_plot, width = 12, height = 5)















# Load the csv file
file_path <- "/Users/sebastianherbst/Dissertation/Data processing/Output/Tree_no_tree_t_test_results.csv"
overall_results_df <- read_csv(file_path)

# Ensure that the column names are as expected
# You mentioned the columns are SITE, Pollutant, t_statistic, p_value, mean_difference, conf_low, conf_high
# You may want to rename columns if they are not already matching your expectations

# Adjust the grouping in your dataframe to include both Pollutant and Site
overall_results_df <- overall_results_df %>%
  mutate(Pollutant_Site = paste(Pollutant, SITE, sep = " - "))

LL_data <- overall_results_df %>%
  filter(SITE %in% c('LL Park', 'LL Street'))


LL_plot <- ggplot(LL_data, aes(x = SITE, y = mean_difference, fill = p_value < 0.05)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.2), width = 0.3) +  # Bar plot for t-test statistics
  geom_errorbar(aes(ymin = conf_low, ymax = conf_high), width = 0.15, color = "black") +  # Error bars for confidence intervals
  theme_minimal() +
  labs(title = "Mean difference of measurements within selected sites",
       x = "Site",
       y = "Mean difference",
       fill = "Significance (p < 0.05)") +
  scale_fill_manual(values = c("FALSE" = "skyblue", "TRUE" = "salmon")) +  # Red for significant results, blue for non-significant
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 10),
        legend.key.size = unit(0.4, "cm"),
        legend.text = element_text(size = 8),
        legend.title = element_text(size = 7),
        legend.position = "right") +
  facet_wrap(~ Pollutant, scales = "free_x", nrow = 1)

LL_plot
ggsave("/Users/sebastianherbst/Dissertation/Data processing/R_results/LL_comp.png", plot = LL_plot, height = 3, width = 10)



NC_data <- overall_results_df %>%
  filter(SITE %in% c('NC Park', 'NC Street'))


NC_plot <- ggplot(NC_data, aes(x = SITE, y = mean_difference, fill = p_value < 0.05)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.2), width = 0.3) +  # Bar plot for t-test statistics
  geom_errorbar(aes(ymin = conf_low, ymax = conf_high), width = 0.15, color = "black") +  # Error bars for confidence intervals
  theme_minimal() +
  labs(title = "Mean difference of measurements within selected sites",
       x = "Site",
       y = "Mean difference",
       fill = "Significance (p < 0.05)") +
  scale_fill_manual(values = c("FALSE" = "skyblue", "TRUE" = "salmon")) +  # Red for significant results, blue for non-significant
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 10),
        legend.key.size = unit(0.4, "cm"),
        legend.text = element_text(size = 8),
        legend.title = element_text(size = 7),
        legend.position = "right") +
  facet_wrap(~ Pollutant, scales = "free_x", nrow = 1)

NC_plot
ggsave("/Users/sebastianherbst/Dissertation/Data processing/R_results/NC_comp.png", plot = NC_plot, height = 3, width = 10)


A2_data <- overall_results_df %>%
  filter(SITE %in% c('A2 Park', 'A2 Street'))


A2_plot <- ggplot(A2_data, aes(x = SITE, y = mean_difference, fill = p_value < 0.05)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.2), width = 0.3) +  # Bar plot for t-test statistics
  geom_errorbar(aes(ymin = conf_low, ymax = conf_high), width = 0.15, color = "black") +  # Error bars for confidence intervals
  theme_minimal() +
  labs(title = "Mean difference of measurements within selected sites",
       x = "Site",
       y = "Mean difference",
       fill = "Significance (p < 0.05)") +
  scale_fill_manual(values = c("FALSE" = "skyblue", "TRUE" = "salmon")) +  # Red for significant results, blue for non-significant
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 10),
        legend.key.size = unit(0.4, "cm"),
        legend.text = element_text(size = 8),
        legend.title = element_text(size = 7),
        legend.position = "right") +
  facet_wrap(~ Pollutant, scales = "free_x", nrow = 1)

A2_plot
ggsave("/Users/sebastianherbst/Dissertation/Data processing/R_results/A2_comp.png", plot = A2_plot, height = 3, width = 10)



All_comp_data <- overall_results_df %>%
  filter(SITE %in% c('All Park', 'All Street'))


All_comp_plot <- ggplot(All_comp_data, aes(x = SITE, y = mean_difference, fill = p_value < 0.05)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.2), width = 0.3) +  # Bar plot for t-test statistics
  geom_errorbar(aes(ymin = conf_low, ymax = conf_high), width = 0.15, color = "black") +  # Error bars for confidence intervals
  theme_minimal() +
  labs(title = "Mean difference of measurements within selected sites",
       x = "Site",
       y = "Mean difference",
       fill = "Significance (p < 0.05)") +
  scale_fill_manual(values = c("FALSE" = "skyblue", "TRUE" = "salmon")) +  # Red for significant results, blue for non-significant
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 10),
        legend.key.size = unit(0.4, "cm"),
        legend.text = element_text(size = 8),
        legend.title = element_text(size = 7),
        legend.position = "right") +
  facet_wrap(~ Pollutant, scales = "free_x", nrow = 1)

All_comp_plot
ggsave("/Users/sebastianherbst/Dissertation/Data processing/R_results/all_comp.png", plot = All_comp_plot, height = 3, width = 10)



#Overall results - no distinction between park or street
All_data <- overall_results_df %>%
  filter(SITE %in% c('All All'))

All_plot <- ggplot(All_data, aes(x = Pollutant, y = mean_difference, fill = p_value < 0.05)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.2), width = 0.3) +  # Bar plot for t-test statistics
  geom_errorbar(aes(ymin = conf_low, ymax = conf_high), width = 0.15, color = "black") +  # Error bars for confidence intervals
  theme_minimal() +
  labs(title = "Mean difference of measurements across all sites",
       x = "Pollutant",
       y = "Mean difference",
       fill = "Significance (p < 0.05)") +
  scale_fill_manual(values = c("FALSE" = "skyblue", "TRUE" = "salmon")) +  # Red for significant results, blue for non-significant
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 10),
        legend.key.size = unit(0.4, "cm"),
        legend.text = element_text(size = 8),
        legend.title = element_text(size = 7),
        legend.position = "right") +
  facet_wrap(~ Pollutant, scales = "free_x", nrow = 1)

All_plot
ggsave("/Users/sebastianherbst/Dissertation/Data processing/R_results/All.png", plot = All_plot, height = 2.5, width = 10)
