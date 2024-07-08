## R script classifies measurements as within d (distance to next tree, set in comb.sens.tree.py)
# or 'no tree nearby' - these segments are distinguished by species.
# T-test analysis is performed between the air quality measurement average under each species-specific segment
# and the closest (prev, next) non-tree segments for that species' segment.
# Results show t-value and significance (p<0.05) for prev/next and combined (prev/next closest non-tree segment)
# separately.

# File uses 'Output/Output- all_air_location_tree/' file created from comb.sens.tree.py 
# Possible link to database commented out below

# Load packages
library(dplyr)
library(readr)
library(ggplot2)
library(tidyr)
library(stringr)
library(rjson)
library(DBI)

# Possible connection to postgres database
config <- fromJSON(file="import.config.json")
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
  host = db_host,
  port = db_port,
  dbname = db_name,
  user = db_user,
  password = db_password
)

# Retrieve data
query <- "SELECT * FROM sensor.dist_5"
data <- dbGetQuery(con, query)

# dbDisconnect(con)



# Load data
#path_name <- "/Users/sebastianherbst/Dissertation/Data processing/Output/Output - all_air_location_tree/2024-06-28_CM_5m_all_air_tree_data.csv"
#data <- read_csv(path_name)

# Extract 'd' from path_name
d <- 5#str_extract(path_name, "\\d+m")

# Prepare data and prepare for t-tests - create segments

# Replace nan in tree_name with 'No_tree'
data$tree_name <- as.factor(ifelse(is.na(data$tree_name), "No_tree", as.character(data$tree_name)))

# Group tree segments together
# Find continuous tree segments
data <- data %>%
  mutate(segment_id = cumsum(c(TRUE, diff(as.numeric(tree_name != "No_tree")) != 0)))

# Separate tree and non-tree segments
data <- data %>%
  mutate(is_tree_segment = tree_name != "No_tree")

# Assign group_ids to consecutive tree segments
data <- data %>%
  group_by(segment_id) %>%
  mutate(group_id = if_else(is_tree_segment, lag(segment_id), NA_integer_)) %>%
  fill(group_id, .direction = "updown") %>%
  ungroup()

# Find the next non-tree segment for each grouped tree segment

# Define function to find closest non-tree segment
find_nearest_no_tree <- function(df, pollutant) {
  tree_groups <- df %>%
    filter(is_tree_segment) %>%
    group_by(group_id, tree_name) %>%
    summarize(avg_tree = mean(.data[[pollutant]], na.rm = TRUE), .groups = 'drop') # averages pollutant data for tree segments
  
  no_tree_segments <- df %>%
    filter(!is_tree_segment) %>%
    group_by(segment_id) %>%
    summarize(avg_no_tree = mean(.data[[pollutant]], na.rm = TRUE), .groups = 'drop') # averages pollutant data for no-tree segments
  
  tree_groups <- tree_groups %>%
    rowwise() %>%
    mutate(
      previous_no_tree_segment = ifelse(
        any(no_tree_segments$segment_id < group_id),
        max(no_tree_segments$segment_id[no_tree_segments$segment_id < group_id], na.rm = TRUE), 
        NA
      ), # finds closest possible previous no-tree segment (labelled in order - prev is next smaller no-tree segment)
      next_no_tree_segment = ifelse(
        any(no_tree_segments$segment_id > group_id),
        min(no_tree_segments$segment_id[no_tree_segments$segment_id > group_id], na.rm = TRUE),
        NA
      ) # finds closest possible next no-tree segment (labelled in order - next is next bigger no-tree segment)
    ) %>%
    ungroup()
  
  # Join the no-tree segments to get their averages for t-test analysis later
  comparison_data <- tree_groups %>%
    left_join(no_tree_segments, by = c("previous_no_tree_segment" = "segment_id"), suffix = c("_tree", "_prev_no_tree")) %>% # joins prev no-tree segments to each tree segment
    left_join(no_tree_segments, by = c("next_no_tree_segment" = "segment_id"), suffix = c("", "_next_no_tree")) %>% # joins next no-tree segment to each tree segment
  
  return(comparison_data)
}

# Define function to perform t-tests for a given pollutant
perform_analysis <- function(data, pollutant) {
  comparison_data <- find_nearest_no_tree(data, pollutant)
  
  #rename prev and next _no_tree segments to make it clearer what is being worked with in each segment
  comparison_data <- comparison_data %>%
    rename(
      avg_prev_no_tree = avg_no_tree,
      avg_next_no_tree = avg_no_tree_next_no_tree
    )
  
  # Combine the previous and next non-tree segments
  comparison_data <- comparison_data %>%
    rowwise() %>%
    mutate(avg_combined_no_tree = mean(c(avg_prev_no_tree, avg_next_no_tree), na.rm = TRUE)) %>%
    ungroup()

  
  # Check if there are enough non-NA values to perform t-tests - minimum is 2
  if (sum(!is.na(comparison_data$avg_prev_no_tree)) < 2 || sum(!is.na(comparison_data$avg_next_no_tree)) < 2 || var(comparison_data$avg_tree, na.rm = TRUE) == 0) {      #has to be met for prev and next no tree as well as tree - t-test wont work otherwise
    return(list(overall_prev = NA, overall_next = NA, overall_combined = NA, by_species = NA, comparison_data = comparison_data)) #return na values if condition isnt met
  }
  
  # Paired t-test comparing pm under trees with closest previous no-tree segments
  if (var(comparison_data$avg_prev_no_tree, na.rm = TRUE) == 0) {
    t_test_result_prev <- list(statistic = NA, p.value = NA)
  } else {
    t_test_result_prev <- t.test(
      comparison_data$avg_tree, 
      comparison_data$avg_prev_no_tree, 
      paired = TRUE, 
      alternative = "two.sided"
    )
  }
  
  #T-test comparing pm under trees with the closest next no-tree
  if (var(comparison_data$avg_next_no_tree, na.rm = TRUE) == 0) {
    t_test_result_next <- list(statistic = NA, p.value = NA)
  } else {
    t_test_result_next <- t.test(
      comparison_data$avg_tree, 
      comparison_data$avg_next_no_tree, 
      paired = TRUE, 
      alternative = "two.sided"
    )
  }
  
  #T-test comparing pm under trees with combined non-tree (prev&next segments)
  if (var(comparison_data$avg_combined_no_tree, na.rm = TRUE) == 0) {
    t_test_result_combined <- list(statistic = NA, p.value = NA)
  } else {
    t_test_result_combined <- t.test(
      comparison_data$avg_tree, 
      comparison_data$avg_combined_no_tree, 
      paired = TRUE, 
      alternative = "two.sided"
    )
  }
  
  #Run whole thing again for each unique species - allows t-test results by species
  #Get unique species
  unique_species <- unique(comparison_data$tree_name)
  
  #Loop the whole thing again over each unique_species - basically the same functions for t-tests
  test_results <- list()
  
  for (species in unique_species) {
    species_data <- comparison_data %>%
      filter(tree_name == species) # Filter data for the current species
    # Check if there are enough observations to perform the t-tests
    if (nrow(species_data) >= 2) { 
      # Perform paired t-test comparing pollutant levels under trees with the nearest previous no-tree segments
      if (sum(!is.na(species_data$avg_prev_no_tree)) >= 2 && var(species_data$avg_prev_no_tree, na.rm = TRUE) != 0) {
        species_t_test_result_prev <- t.test(
          species_data$avg_tree, 
          species_data$avg_prev_no_tree, 
          paired = TRUE, 
          alternative = "two.sided"
        )
      } else {
        species_t_test_result_prev <- list(statistic = NA, p.value = NA) # fills list with na if conditions aren't met (not enough values)
      }
      
      #T-test comparing pollution under trees with the closest next no-tree segments
      if (sum(!is.na(species_data$avg_next_no_tree)) >= 2 && var(species_data$avg_next_no_tree, na.rm = TRUE) != 0) {
        species_t_test_result_next <- t.test(
          species_data$avg_tree, 
          species_data$avg_next_no_tree, 
          paired = TRUE, 
          alternative = "two.sided"
        )
      } else {
        species_t_test_result_next <- list(statistic = NA, p.value = NA)
      }
      
      #T-test comparing pm under trees with the combined non-tree segments (next/prev)
      if (sum(!is.na(species_data$avg_combined_no_tree)) >= 2 && var(species_data$avg_combined_no_tree, na.rm = TRUE) != 0) {
        species_t_test_result_combined <- t.test(
          species_data$avg_tree, 
          species_data$avg_combined_no_tree, 
          paired = TRUE, 
          alternative = "two.sided"
        )
      } else {
        species_t_test_result_combined <- list(statistic = NA, p.value = NA)
      }
      
      #Stores results
      test_results[[species]] <- list(
        species = species,
        t_test_prev = species_t_test_result_prev,
        t_test_next = species_t_test_result_next,
        t_test_combined = species_t_test_result_combined
      )
    } else {
    cat("Not enough data for:", species, "\n") #print message if condition of data amount isn't met
  }
}

return(list(overall_prev = t_test_result_prev, overall_next = t_test_result_next, overall_combined = t_test_result_combined, by_species = test_results, comparison_data = comparison_data))
}





# Function to format t-test results from list into a dataframe
format_t_test_results <- function(results, pollutant) {
  overall_prev <- if (is.list(results$overall_prev) && is.na(results$overall_prev$statistic)) {
    data.frame(
      Test = "All previous non-tree",
      Statistic = NA,
      P_Value = NA,
      Pollutant = pollutant
    )
  } else {
    data.frame(
      Test = "All previous non-tree",
      Statistic = results$overall_prev$statistic,
      P_Value = results$overall_prev$p.value,
      Pollutant = pollutant
    )
  }
  
  overall_next <- if (is.list(results$overall_next) && is.na(results$overall_next$statistic)) {
    data.frame(
      Test = "All next non-tree",
      Statistic = NA,
      P_Value = NA,
      Pollutant = pollutant
    )
  } else {
    data.frame(
      Test = "All next non-tree",
      Statistic = results$overall_next$statistic,
      P_Value = results$overall_next$p.value,
      Pollutant = pollutant
    )
  }
  
  overall_combined <- if (is.list(results$overall_combined) && is.na(results$overall_combined$statistic)) {
    data.frame(
      Test = "Overall non-tree combined",
      Statistic = NA,
      P_Value = NA,
      Pollutant = pollutant
    )
  } else {
    data.frame(
      Test = "Overall non-tree combined",
      Statistic = results$overall_combined$statistic,
      P_Value = results$overall_combined$p.value,
      Pollutant = pollutant
    )
  }
  
  species_results <- lapply(names(results$by_species), function(species) {
    res <- results$by_species[[species]]
    data.frame(
      Species = species,
      Test = c("Previous non-tree", "Next non-tree", "Previous & next non-tree"),
      Statistic = c(res$t_test_prev$statistic, res$t_test_next$statistic, res$t_test_combined$statistic),
      P_Value = c(res$t_test_prev$p.value, res$t_test_next$p.value, res$t_test_combined$p.value),
      Pollutant = pollutant
    )
  }) %>% bind_rows()
  
  bind_rows(overall_prev, overall_next, overall_combined, species_results)
}



#Run the perform_analysis function for pm10, pm2.5, pm1, pm4, and temperature2
results_pm10 <- perform_analysis(data, "pm_10")
results_pm25 <- perform_analysis(data, "pm_25")
results_pm1 <- perform_analysis(data, "pm_1")
results_pm4 <- perform_analysis(data, "pm_4")
#results_temp <- perform_analysis(data, "temperature2")

# Format results into data frames
results_df_pm10 <- format_t_test_results(results_pm10, "PM10")
results_df_pm25 <- format_t_test_results(results_pm25, "PM2.5")
results_df_pm1 <- format_t_test_results(results_pm1, "PM1")
results_df_pm4 <- format_t_test_results(results_pm4, "PM4")
#results_df_temp <- format_t_test_results(results_temp, "Temperature")  #(not enough data rn - temp should be okay for larger datasets though)

# Combine all results into one data frame
all_results_df <- bind_rows(results_df_pm10, results_df_pm25, results_df_pm1, results_df_pm4)#, results_df_temp)




# Filter for statistically significant results (p-value < 0.05)
significant_results_df <- all_results_df %>%
  filter(P_Value < 0.05)

print(significant_results_df)


##Take results back apart again to be able to visualise them individually
#Separate into previous/next and combined t-tests
prev_next_results_df <- all_results_df %>%
  filter(Test %in% c("All previous non-tree", "All next non-tree", "Previous non-tree", "Next non-tree"))
combined_results_df <- all_results_df %>%
  filter(Test %in% c("Overall non-tree combined", "Previous & next non-tree"))

# Separate significant results into previous/next and combined
significant_prev_next_results_df <- significant_results_df %>%
  filter(Test %in% c("All previous non-tree", "All next non-tree", "Previous non-tree", "Next non-tree"))
significant_combined_results_df <- significant_results_df %>%
  filter(Test %in% c("Overall non-tree combined", "Previous & next non-tree"))


##Visualise 
#Visualise previous/next results
ggplot(prev_next_results_df, aes(x = Species, y = Statistic, fill = Test)) +
  geom_bar(stat = "identity", position = position_dodge()) +
  facet_wrap(~Pollutant) +
  theme_minimal() +
  labs(title = paste("T-test Results for Pollutants by Species within", d),
       x = "Species",
       y = "T-test Statistic",
       fill = "Test Type") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

#Plot combined results
ggplot(combined_results_df, aes(x = Species, y = Statistic, fill = Test)) +
  geom_bar(stat = "identity", position = position_dodge()) +
  facet_wrap(~Pollutant) +
  theme_minimal() +
  labs(title = paste("Combined T-test Results for Different Pollutants by Species within", d),
       x = "Species",
       y = "T-test Statistic",
       fill = "Test Type") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# Visualis significant previous/next results
ggplot(significant_prev_next_results_df, aes(x = Species, y = Statistic, fill = Test)) +
  geom_bar(stat = "identity", position = position_dodge()) +
  facet_wrap(~Pollutant) +
  theme_minimal() +
  labs(title = paste("Significant T-test Results (p-value < 0.05) for Different Pollutants by Species within", d),
       x = "Species",
       y = "T-test Statistic",
       fill = "Test Type") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# Significant combined results
ggplot(significant_combined_results_df, aes(x = Species, y = Statistic, fill = Test)) +
  geom_bar(stat = "identity", position = position_dodge()) +
  facet_wrap(~Pollutant) +
  theme_minimal() +
  labs(title = paste("Significant T-test Results (p-value < 0.05) for Pollutants by Species within", d),
       x = "Species",
       y = "T-test Statistic",
       fill = "Test Type") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))



## Save results to be able to check things
# Save results as dataframe
t_test_results_df <- all_results_df
significant_t_test_results_df <- significant_results_df


#Save comparison data to be able to check and see
comparison_data_pm10 <- results_pm10$comparison_data
comparison_data_pm25 <- results_pm25$comparison_data
comparison_data_pm1 <- results_pm1$comparison_data
comparison_data_pm4 <- results_pm4$comparison_data
#comparison_data_temp <- results_temp$comparison_data

    