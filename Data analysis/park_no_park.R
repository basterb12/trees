#This script creates two sets of data (park and no park) by using spatial envelopes in the database query. 
#Kolmogorov-Smirnoff test is performed to check for normality - if not normal Mann-Whitney U-test is performed, if normal then paired t-test.

library(dplyr)
library(readr)
library(mgcv)
library(ggplot2)
library(DBI)
library(RPostgres)
library(rjson)
library(patchwork)

# Connection to PostgreSQL database - specify where your json file is saved
config <- fromJSON(file=#"SPECIFY/import.config.json")
print(config)
print(config['database'][[1]])

# Connect to the database
con <- dbConnect(
  RPostgres::Postgres(),
  host = "localhost",
  port = 5439,
  dbname = "airquality_db",
  user = "postgres",
  password = "postgres"
)

plot_file <- #"FILE WHERE YOU WANT YOUR PLOT TO BE SAVED"
  
# Retrieve data - Use query functions to specify what measurements you want to compare - here it is site LL from Date 2024-06-17
# The envelope here means data selected is NOT from within the parks
query <- "SELECT * FROM sensor.dist_20
WHERE location = 'LL'
AND DATE(time) = '2024-06-17'
AND NOT(
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
)
;"

#This query selects the data from the park - makes sure its the same period and site to be able to compare
query_park <- "
SELECT * 
FROM sensor.dist_20
WHERE location = 'LL'
AND DATE(time) = '2024-06-17'
AND (
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
)

;"


data <- dbGetQuery(con, query)
data_park <- dbGetQuery(con, query_park)

# Mapping of pollutant variable names to display names
pollutant_names <- c(
  "pm_1" = "PM 1",
  "pm_25" = "PM 2.5",
  "pm_4" = "PM 4",
  "pm_10" = "PM 10",
  "temperature2" = "Temperature"
)

# Function to perform statistical tests
perform_stat_tests <- function(data1, data2, pollutant, num_permutations = 2000) {
  data_combined <- data1 %>%
    mutate(location = "General Area") %>%
    bind_rows(data2 %>% mutate(location = "Park Area"))
  
  # Check for sufficient data before performing tests
  if (nrow(data_combined %>% filter(location == "General Area")) < 10 | nrow(data_combined %>% filter(location == "Park Area")) < 10) {
    cat(paste("Not enough data for", pollutant, "\n"))
    return(NULL)
  }
  
  # Check for normality using Kolmogorov-Smirnov test
  ks_test_data1 <- ks.test(data_combined %>% filter(location == "General Area") %>% pull(!!sym(pollutant)), 
                           "pnorm", mean(data_combined %>% filter(location == "General Area") %>% pull(!!sym(pollutant)), na.rm = TRUE), 
                           sd(data_combined %>% filter(location == "General Area") %>% pull(!!sym(pollutant)), na.rm = TRUE))
  ks_test_data2 <- ks.test(data_combined %>% filter(location == "Park Area") %>% pull(!!sym(pollutant)), 
                           "pnorm", mean(data_combined %>% filter(location == "Park Area") %>% pull(!!sym(pollutant)), na.rm = TRUE), 
                           sd(data_combined %>% filter(location == "Park Area") %>% pull(!!sym(pollutant)), na.rm = TRUE))

  
  # Perform Mann-Whitney U test if data is not normally distributed
  if (ks_test_data1$p.value <= 0.05 | ks_test_data2$p.value <= 0.05) {
    wilcox_test_result <- wilcox.test(data_combined %>% filter(location == "General Area") %>% pull(!!sym(pollutant)), 
                                      data_combined %>% filter(location == "Park Area") %>% pull(!!sym(pollutant)), 
                                      paired = FALSE, alternative = "two.sided")
    stat_test_results <- list(wilcox_test = wilcox_test_result)
    # Print test results
    cat(paste("Mann-Whitney U test result for", pollutant, ":\n"))
    print(wilcox_test_result)
  } else {
    t_test_result <- t.test(data_combined %>% filter(location == "General Area") %>% pull(!!sym(pollutant)), 
                            data_combined %>% filter(location == "Park Area") %>% pull(!!sym(pollutant)), 
                            paired = FALSE, alternative = "two.sided")
    stat_test_results <- list(t_test = t_test_result)
    cat(paste("T-test result for", pollutant, ":\n"))
    print(t_test_result)
  }
  
  # # Perform permutation test
  # observed_diff <- mean(data_combined %>% filter(location == "General Area") %>% pull(!!sym(pollutant))) -
  #   mean(data_combined %>% filter(location == "Park Area") %>% pull(!!sym(pollutant)))
  # 
  # perm_diffs <- replicate(num_permutations, {
  #   perm_data <- data_combined %>%
  #     mutate(location = sample(location))
  #   mean(perm_data %>% filter(location == "General Area") %>% pull(!!sym(pollutant))) -
  #     mean(perm_data %>% filter(location == "Park Area") %>% pull(!!sym(pollutant)))
  # })
  # 
  # p_value <- mean(abs(perm_diffs) >= abs(observed_diff))
  # cat(paste("Permutation test p-value for", pollutant, ":", p_value, "\n"))
  # stat_test_results$perm_test <- list(observed_diff = observed_diff, p_value = p_value)

  # Calculate the mean and standard deviation for each group
  summary_stats <- data_combined %>%
    group_by(location) %>%
    summarise(
      mean_value = mean(!!sym(pollutant), na.rm = TRUE),
      sd_value = sd(!!sym(pollutant), na.rm = TRUE)
    )
  
  list(
    ks_test_data1 = ks_test_data1,
    ks_test_data2 = ks_test_data2,
    stat_test_results = stat_test_results,
    summary_stats = summary_stats,
    data_combined = data_combined
  )
}


# Perform analysis for each pollutant
analysis_results <- list()
pollutants <- c("pm_1", "pm_25", "pm_4", "pm_10", "temperature2")
for (pollutant in pollutants) {
  result <- perform_stat_tests(data, data_park, pollutant)
  if (!is.null(result)) {
    analysis_results[[pollutant]] <- result
  }
}

# Visualization with legend
plots <- list()
for (pollutant in pollutants) {
  if (is.null(analysis_results[[pollutant]])) next
  
  results <- analysis_results[[pollutant]]
  data_combined <- results$data_combined
  summary_stats <- results$summary_stats
  
  # Create ggplot with the required layers
  p <- ggplot(data_combined, aes(x = location, y = .data[[pollutant]], fill = location)) +
    geom_jitter(position = position_jitter(width = 0.19), alpha = 0.5, size = 0.3) +
    stat_summary(fun.data = mean_sdl, fun.args = list(mult = 1), geom = "crossbar", width = 0.4, color = "black", alpha = 0.5) +
    geom_hline(data = summary_stats %>% filter(location == "General Area"), aes(yintercept = mean_value), color = "red", linetype = "dashed", size = 1) +
    geom_hline(data = summary_stats %>% filter(location == "Park Area"), aes(yintercept = mean_value), color = "blue", linetype = "dashed", size = 1) +
    geom_line(data = summary_stats, aes(y = mean_value, color = location), size = 1, show.legend = TRUE) +
    scale_color_manual(values = c("General Area" = "red", "Park Area" = "blue")) +
    labs(title = paste("Average", pollutant_names[[pollutant]], "Measurements"), 
         y = paste(pollutant_names[[pollutant]], "Levels"), 
         x = "Location") +
    theme_minimal() +
    theme(legend.position = "bottom", legend.title = element_blank())
  
  # Store the plot in the list
  plots[[pollutant]] <- p
  
  # Print the individual plot
  print(p)
}

# Combine the plots into a 2x2 grid using patchwork
combined_plot <- (plots[["pm_1"]] | plots[["pm_25"]]) /
  (plots[["pm_4"]] | plots[["temperature2"]])

# Display the combined plot
print(combined_plot)
ggsave(plot_file, plot = combined_plot, height = 4.5, width =10)






# Create a directory to save the results if it doesn't exist
output_dir <- #"YOUR DIRECTORY/park_no_park_results/"
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# Loop through each pollutant in analysis_results
for (pollutant in names(analysis_results)) {
  if (is.null(analysis_results[[pollutant]])) next
  
  # Extract summary stats and statistical test results
  summary_stats <- analysis_results[[pollutant]]$summary_stats
  stat_test_results <- analysis_results[[pollutant]]$stat_test_results
  
  # Save summary_stats as csv
  summary_stats_file <- file.path(output_dir, paste0("summary_stats_", pollutant, ".csv"))
  write.csv(summary_stats, summary_stats_file, row.names = FALSE)
  
  # Save stat_test_results to csv
  if (!is.null(stat_test_results$t_test)) {
    stat_test_result_file <- file.path(output_dir, paste0("t_test_results_", pollutant, ".csv"))
    t_test_results_df <- data.frame(
      test = "t-test",
      estimate = stat_test_results$t_test$estimate,
      p_value = stat_test_results$t_test$p.value,
      conf_low = stat_test_results$t_test$conf.int[1],
      conf_high = stat_test_results$t_test$conf.int[2]
    )
    write.csv(t_test_results_df, stat_test_result_file, row.names = FALSE)
  } else if (!is.null(stat_test_results$wilcox_test)) {
    stat_test_result_file <- file.path(output_dir, paste0("wilcox_test_results_", pollutant, ".csv"))
    wilcox_test_results_df <- data.frame(
      test = "Mann-Whitney U",
      estimate = NA,  # Mann-Whitney U does not provide an estimate like t-test does
      p_value = stat_test_results$wilcox_test$p.value,
      conf_low = NA,  # Mann-Whitney U test does not provide confidence intervals
      conf_high = NA
    )
    write.csv(wilcox_test_results_df, stat_test_result_file, row.names = FALSE)
  }
}

