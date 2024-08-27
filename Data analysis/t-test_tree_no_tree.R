## R script classifies measurements as within d (distance to next tree, set in comb.sens.tree.py)
# or 'no tree nearby' - these segments are distinguished by species.
# T-test analysis is performed between the air quality measurement average under each species-specific segment
# and the closest (prev, next) non-tree segments for that species' segment.
# Results show t-value and significance (p<0.05) for prev/next and combined (prev/next closest non-tree segment) separately.

#GAM is also run to see if there's any effect between dbh and difference between tree and closest non-tree segments.


# File uses 'Output/Output- all_air_location_tree/' file created from comb.sens.tree.py 

# Load packages
library(dplyr)
library(readr)
library(ggplot2)
library(tidyr)
library(stringr)
library(rjson)
library(DBI)
library(zoo)
library(viridis)
library(purrr)
library(mgcv)

#Connection to postgres database
config <- fromJSON(file=#"DIRECTORY/import.config.json")
print(config)
print (config['database'][[1]])
#Connect

db_host <- config['host'][[1]]
db_port <- config['port'][[1]]
db_name <- config['database'][[1]]
db_user <- config['user'][[1]]
db_password <- config['password'][[1]]
print(db_name)

con <- dbConnect(
  RPostgres::Postgres(),
  host = "localhost",
  port = 5439,
  dbname = "airquality_db",
  user = "postgres",
  password = "postgres"
)

#specify your output files
site <- "- All (street)"
plot_file <- "/t_test_plot_All_street.png"
local_plot_file <- "/local_t_test_All_street.png"
csv_result_file <- "/t-test_result.csv"

# Retrieve data
query <- "SELECT * FROM sensor.dist_10
WHERE NOT location = 'CM'
AND NOT (
  ST_Within(
    ST_GeomFromEWKB(sensor_geom),
    ST_MakeEnvelope(-0.0156, 51.4627, -0.0131, 51.464, 4326)
  )
  OR ST_Within(
    ST_GeomFromEWKB(sensor_geom),
    ST_MakeEnvelope(-0.0388, 51.4766, -0.03424, 51.4783, 4326)
  )
  OR ST_Within(
    ST_GeomFromEWKB(sensor_geom),
    ST_MakeEnvelope(-0.0588, 51.4774, -0.0546, 51.4787, 4326)
  )
)"


data <- dbGetQuery(con, query)
 

# Just for naming plots - not really necessary
d <- "10m of trees"

# Linear interpolation for missing temperature2 data
data$temperature2 <- na.approx(data$temperature2, na.rm = FALSE)  # Fill missing data

#Run the script to clean the data
source("~/process_data.R")

# Group tree segments together
data <- data %>%
  mutate(segment_id = cumsum(c(TRUE, diff(as.numeric(tree_name != "no_tree")) != 0)))

# Separate tree and non-tree segments
data <- data %>%
  mutate(is_tree_segment = (tree_name != "no_tree")) #& (diameter_at_breast_height_cm > 20))

# Assign group_ids to consecutive tree segments
data <- data %>%
  group_by(segment_id) %>%
  mutate(group_id = if_else(is_tree_segment, lag(segment_id), NA_integer_)) %>%
  fill(group_id, .direction = "updown") %>%
  ungroup()

# Define function to find closest non-tree segment
find_nearest_no_tree <- function(df, pollutant) {
  tree_groups <- df %>%
    filter(is_tree_segment) %>%
    group_by(group_id, tree_name) %>%
    summarize(avg_tree = mean(.data[[pollutant]], na.rm = TRUE),
    avg_dbh = mean(ifelse(diameter_at_breast_height_cm > 75, NA, diameter_at_breast_height_cm), na.rm = TRUE), .groups = 'drop')
  
  no_tree_segments <- df %>%
    filter(!is_tree_segment) %>%
    group_by(segment_id) %>%
    summarize(avg_no_tree = mean(.data[[pollutant]], na.rm = TRUE),
    avg_dbh = mean(ifelse(diameter_at_breast_height_cm > 75, NA, diameter_at_breast_height_cm), na.rm = TRUE), .groups = 'drop')
  
  tree_groups <- tree_groups %>%
    rowwise() %>%
    mutate(
      previous_no_tree_segment = ifelse(
        any(no_tree_segments$segment_id < group_id),
        max(no_tree_segments$segment_id[no_tree_segments$segment_id < group_id], na.rm = TRUE), 
        NA
      ),
      next_no_tree_segment = ifelse(
        any(no_tree_segments$segment_id > group_id),
        min(no_tree_segments$segment_id[no_tree_segments$segment_id > group_id], na.rm = TRUE),
        NA
      )
    ) %>%
    ungroup()
  
  comparison_data <- tree_groups %>%
    left_join(no_tree_segments, by = c("previous_no_tree_segment" = "segment_id"), suffix = c("_tree", "_prev_no_tree")) %>%
    left_join(no_tree_segments, by = c("next_no_tree_segment" = "segment_id"), suffix = c("", "_next_no_tree"))

  
  return(comparison_data)
}

# Define function to perform t-tests for a given pollutant
perform_analysis <- function(data, pollutant) {
  comparison_data <- find_nearest_no_tree(data, pollutant)
  
  comparison_data <- comparison_data %>%
    rename(
      avg_prev_no_tree = avg_no_tree,
      avg_next_no_tree = avg_no_tree_next_no_tree
    ) %>%
    rowwise() %>%
    mutate(avg_combined_no_tree = mean(c(avg_prev_no_tree, avg_next_no_tree), na.rm = TRUE)) %>%
    ungroup()
  
  comparison_data <- comparison_data %>%
    mutate(diff_tree_no_tree = avg_tree - ((avg_prev_no_tree + avg_next_no_tree)/2))
  
  if (sum(!is.na(comparison_data$avg_prev_no_tree)) < 2 || 
      sum(!is.na(comparison_data$avg_next_no_tree)) < 2 || 
      var(comparison_data$avg_tree, na.rm = TRUE) == 0) {
    return(list(overall_prev = list(statistic = NA, p.value = NA), 
                overall_next = list(statistic = NA, p.value = NA), 
                overall_combined = list(statistic = NA, p.value = NA), 
                by_species = list(), comparison_data = comparison_data))
    
  }
  
  t_test_result_prev <- if (var(comparison_data$avg_prev_no_tree, na.rm = TRUE) == 0) {
    list(statistic = NA, p.value = NA)
  } else {
    t.test(comparison_data$avg_tree, comparison_data$avg_prev_no_tree, paired = TRUE, alternative = "two.sided")
  }
  
  t_test_result_next <- if (var(comparison_data$avg_next_no_tree, na.rm = TRUE) == 0) {
    list(statistic = NA, p.value = NA)
  } else {
    t.test(comparison_data$avg_tree, comparison_data$avg_next_no_tree, paired = TRUE, alternative = "two.sided")
  }
  
  t_test_result_combined <- if (var(comparison_data$avg_combined_no_tree, na.rm = TRUE) == 0) {
    list(statistic = NA, p.value = NA)
  } else {
    t.test(comparison_data$avg_tree, comparison_data$avg_combined_no_tree, paired = TRUE, alternative = "two.sided")
  }
  
  return(list(overall_prev = t_test_result_prev, 
              overall_next = t_test_result_next, 
              overall_combined = t_test_result_combined, 
              comparison_data = comparison_data))
}

# Function to format t-test results into a data frame
format_t_test_results <- function(results, pollutant) {
  overall_prev <- if (is.list(results$overall_prev) && is.na(results$overall_prev$statistic)) {
    data.frame(Test = "All previous non-tree", Statistic = NA, P_Value = NA, Pollutant = pollutant, mean_difference = NA, conf_low = NA, conf_high = NA)
  } else {
    data.frame(Test = "All previous non-tree", Statistic = results$overall_prev$statistic, P_Value = results$overall_prev$p.value, Pollutant = pollutant, mean_difference = results$overall_prev$estimate, conf_low = results$overall_prev$conf.int[1], conf_high = results$overall_prev$conf.int[2])
  }
  
  overall_next <- if (is.list(results$overall_next) && is.na(results$overall_next$statistic)) {
    data.frame(Test = "All next non-tree", Statistic = NA, P_Value = NA, Pollutant = pollutant, mean_difference = NA, conf_low = NA, conf_high = NA)
  } else {
    data.frame(Test = "All next non-tree", Statistic = results$overall_next$statistic, P_Value = results$overall_next$p.value, Pollutant = pollutant, mean_difference = results$overall_next$estimate, conf_low = results$overall_next$conf.int[1], conf_high = results$overall_next$conf.int[2])
  }
  
  overall_combined <- if (is.list(results$overall_combined) && is.na(results$overall_combined$statistic)) {
    data.frame(Test = "Overall non-tree combined", Statistic = NA, P_Value = NA, Pollutant = pollutant, mean_difference = NA, conf_low = NA, conf_high = NA)
  } else {
    data.frame(Test = "Overall non-tree combined", Statistic = results$overall_combined$statistic, P_Value = results$overall_combined$p.value, Pollutant = pollutant, mean_difference = results$overall_combined$estimate, conf_low = results$overall_combined$conf.int[1], conf_high = results$overall_combined$conf.int[2])
  }
  
  bind_rows(overall_prev, overall_next, overall_combined)
}



# Run the perform_analysis function for pollutants and temperature2
results_pm10 <- perform_analysis(data, "pm_10")
results_pm25 <- perform_analysis(data, "pm_25")
results_pm1 <- perform_analysis(data, "pm_1")
results_pm4 <- perform_analysis(data, "pm_4")
results_temp <- perform_analysis(data, "temperature2")

# Format results into data frames
results_df_pm10 <- format_t_test_results(results_pm10, "PM10")
results_df_pm25 <- format_t_test_results(results_pm25, "PM2.5")
results_df_pm1 <- format_t_test_results(results_pm1, "PM1")
results_df_pm4 <- format_t_test_results(results_pm4, "PM4")
results_df_temp <- format_t_test_results(results_temp, "Temperature")

# Combine all results into one data frame
all_results_df <- bind_rows(results_df_pm10, results_df_pm25, results_df_pm1, results_df_pm4, results_df_temp)
overall_results_df <- all_results_df %>%
  filter(Test == "Overall non-tree combined")

# Filter for statistically significant results (p-value < 0.05)
significant_results_df <- all_results_df %>%
  filter(P_Value < 0.05)


# Visualization for all t-test results with confidence intervals
local_t_test_plot <- ggplot(overall_results_df, aes(x = Pollutant, y = mean_difference, fill = P_Value < 0.05)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.4), width = 0.3) +  # Bar plot for t-test statistics
  geom_errorbar(aes(ymin = conf_low, ymax = conf_high), width = 0.2, color = "black") +  # Error bars for confidence intervals
  theme_minimal() +
  labs(title = paste("Mean difference of measurements within", d),
       x = "Pollutant",
       y = "Mean difference",
       fill = "Significant (p < 0.05)") +
  scale_fill_manual(values = c("FALSE" = "skyblue", "TRUE" = "salmon")) +  # Red for significant results, blue for non-significant
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 10),
        legend.key.size = unit(0.4, "cm"),
        legend.text = element_text(size = 8),
        legend.title = element_text(size = 7),
        legend.position = "right")

local_t_test_plot
#ggsave(local_plot_file, plot = local_t_test_plot, width = 10, height = 3)

# Extract and combine comparison data for all pollutants
comparison_data_pm10 <- results_pm10$comparison_data %>% mutate(Pollutant = "PM10")
comparison_data_pm25 <- results_pm25$comparison_data %>% mutate(Pollutant = "PM2.5")
comparison_data_pm1 <- results_pm1$comparison_data %>% mutate(Pollutant = "PM1")
comparison_data_pm4 <- results_pm4$comparison_data %>% mutate(Pollutant = "PM4")
comparison_data_temp <- results_temp$comparison_data %>% mutate(Pollutant = "Temperature")

# Combine all comparison data into one DataFrame
comparison_data_all <- bind_rows(comparison_data_pm1, comparison_data_pm25, comparison_data_pm4, comparison_data_pm10, comparison_data_temp)




# Save results to be able to check things
# Save results as a DataFrame
t_test_results_df <- all_results_df
significant_t_test_results_df <- significant_results_df

# Save the filtered DataFrame to a csv
#write.csv(significant_combined_overall_df, "/Users/sebastianherbst/Dissertation/Data processing/significant_combined_overall_df.csv", row.names = FALSE)
write.csv(overall_results_df, "/overall_tree_no_tree_result.csv", row.names = FALSE)

# Save comparison data to be able to check and see
comparison_data_pm10 <- results_pm10$comparison_data
comparison_data_pm25 <- results_pm25$comparison_data
comparison_data_pm1 <- results_pm1$comparison_data
comparison_data_pm4 <- results_pm4$comparison_data
comparison_data_temp <- results_temp$comparison_data


# Perform paired t-test between avg_tree and avg_combined_no_tree for each pollutant
t_test_results_combined <- comparison_data_all %>%
  group_by(Pollutant) %>%
  summarize(
    t_test_result = list(
      t.test(
        x = avg_tree,
        y = avg_combined_no_tree,
        paired = TRUE,
        alternative = "two.sided"
      )
    ),
    t_statistic = map_dbl(t_test_result, ~ .x$statistic),
    p_value = map_dbl(t_test_result, ~ .x$p.value),
    mean_difference = map_dbl(t_test_result, ~ .x$estimate),
    conf_low = map_dbl(t_test_result, ~ .x$conf.int[1]),
    conf_high = map_dbl(t_test_result, ~ .x$conf.int[2])
  )

# Display the t-test results
print(t_test_results_combined)

# Reshape data for plotting and create overall averages
overall_averages <- comparison_data_all %>%
  group_by(Pollutant) %>%
  summarize(avg_tree_overall = mean(avg_tree, na.rm = TRUE),
            avg_no_tree_overall = mean(avg_combined_no_tree, na.rm = TRUE))

overall_averages_long <- overall_averages %>%
  pivot_longer(cols = c(avg_tree_overall, avg_no_tree_overall),
               names_to = "Segment_Type",
               values_to = "Average_Concentration") %>%
  mutate(Segment_Type = recode(Segment_Type, 
                               "avg_tree_overall" = "Tree Segment Average", 
                               "avg_no_tree_overall" = "Combined No-Tree Average"))



# Create a plot of the mean differences with error bars for confidence intervals
t_test_plot <- ggplot(t_test_results_combined, aes(x = Pollutant, y = mean_difference)) +
  geom_bar(stat = "identity", fill = "skyblue", width = 0.4) +  # Bar plot for mean differences
  geom_errorbar(aes(ymin = conf_low, ymax = conf_high), width = 0.2, color = "red") +  # Error bars for confidence intervals
  theme_minimal() +
  labs(title = paste("Mean differences of measurements within 10m of a tree and those outside the radius",site),
       x = "Pollutant",
       y = "Mean Difference") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 10),
        legend.key.size = unit(0.4, "cm"),
        legend.text = element_text(size = 8),
        legend.title = element_text(size = 7),
        legend.position = "right")

t_test_plot
#ggsave(plot_file, plot = t_test_plot, width = 10, height = 3)


#Run gams to see if there is any effect between difference in tree_no_tree and dbh
#prep gam
gam_pm1 <- gam(diff_tree_no_tree ~ s(avg_dbh_tree), method='REML', data = comparison_data_pm1)
gam_pm25 <- gam(diff_tree_no_tree ~ s(avg_dbh_tree), method='REML', data = comparison_data_pm25)
gam_pm4 <- gam(diff_tree_no_tree ~ s(avg_dbh_tree), method='REML', data = comparison_data_pm4)
gam_pm10 <- gam(diff_tree_no_tree ~ s(avg_dbh_tree), method='REML', data = comparison_data_pm10)
gam_temp <- gam(diff_tree_no_tree ~ s(avg_dbh_tree), method='REML', data = comparison_data_temp)


plot(gam_pm1, main = "Effect of DBH on PM1")
plot(gam_pm25, main = "Effect of DBH on PM25")
plot(gam_pm4, main = "Effect of DBH on PM4")
plot(gam_pm10, main = "Effect of DBH on PM10")
plot(gam_temp, main = "Effect of DBH on Temperature")


#Restrict for plotting
comparison_data_pm1 <- comparison_data_pm1 %>%
  arrange(diff_tree_no_tree) %>%
  slice(6:(n() - 30))
comparison_data_pm25 <- comparison_data_pm25 %>%
  arrange(diff_tree_no_tree) %>%
  slice(6:(n() - 30))
comparison_data_pm4 <- comparison_data_pm4 %>%
  arrange(diff_tree_no_tree) %>%
  slice(6:(n() - 30))
comparison_data_pm10 <- comparison_data_pm10 %>%
  arrange(diff_tree_no_tree) %>%
  slice(6:(n() - 30))
comparison_data_temp <- comparison_data_temp %>%
  arrange(diff_tree_no_tree) %>%
  slice(6:(n() - 20))

# Visualize the results
ggplot(comparison_data_pm1, aes(x = avg_dbh_tree, y = diff_tree_no_tree)) +
  geom_point() +
  geom_smooth(method = "gam", formula = y ~ s(x)) +
  labs(title = "Effect of DBH on PM1", x = "DBH", y = "PM1 abatement")

ggplot(comparison_data_pm25, aes(x = avg_dbh_tree, y = diff_tree_no_tree)) +
  geom_point() +
  geom_smooth(method = "gam", formula = y ~ s(x)) +
  labs(title = "Effect of DBH on PM25", x = "DBH", y = "PM25 abatement")

ggplot(comparison_data_pm4, aes(x = avg_dbh_tree, y = diff_tree_no_tree)) +
  geom_point() +
  geom_smooth(method = "gam", formula = y ~ s(x)) +
  labs(title = "Effect of DBH on PM4", x = "DBH", y = "PM4 abatement")

ggplot(comparison_data_pm10, aes(x = avg_dbh_tree, y = diff_tree_no_tree)) +
  geom_point() +
  geom_smooth(method = "gam", formula = y ~ s(x)) +
  labs(title = "Effect of DBH on PM10", x = "DBH", y = "PM10 abatement")

ggplot(comparison_data_temp, aes(x = avg_dbh_tree, y = diff_tree_no_tree)) +
  geom_point() +
  geom_smooth(method = "gam", formula = y ~ s(x)) +
  labs(title = "Effect of DBH on Temperature", x = "DBH", y = "Temperature reduction")


summary(gam_pm1)
summary(gam_pm25)
summary(gam_pm4)
summary(gam_pm10)
summary(gam_temp)



#write to csv
t_test_results_combined_clean <- t_test_results_combined %>%
  select(-t_test_result)  # Remove the 't_test_result' column

write.csv(t_test_results_combined_clean, csv_result_file)

  
