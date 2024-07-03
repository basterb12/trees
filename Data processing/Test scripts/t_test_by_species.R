# Load necessary libraries
library(dplyr)
library(readr)
library(ggplot2)
library(mgcv)
library(tidyr)

# Load the data
data <- read_csv("/Users/sebastianherbst/Dissertation/Data processing/Output/Output - all_air_location_tree/2024-06-28_CM_5m_all_air_tree_data.csv")

# Convert 'tree_name' to a factor, treating 'NaN' appropriately
data$tree_name <- as.factor(ifelse(is.na(data$tree_name), "No_Tree", as.character(data$tree_name)))

# Step 1: Identify and label continuous segments
data <- data %>%
  mutate(segment_id = cumsum(c(TRUE, diff(as.numeric(tree_name != "No_Tree")) != 0)))

# Step 2: Group consecutive tree segments together
# Create a flag for tree and non-tree segments
data <- data %>%
  mutate(is_tree_segment = tree_name != "No_Tree")

# Assign group ids to consecutive tree segments
data <- data %>%
  group_by(segment_id) %>%
  mutate(group_id = if_else(is_tree_segment, lag(segment_id), NA_integer_)) %>%
  fill(group_id, .direction = "updown") %>%
  ungroup()

# Step 3: Find the nearest non-tree segments for each group of tree segments
# Create a function to find the closest non-tree segments
find_nearest_no_tree <- function(df) {
  tree_groups <- df %>%
    filter(is_tree_segment) %>%
    group_by(group_id, tree_name) %>%
    summarize(avg_pm_10_tree = mean(pm_10, na.rm = TRUE), .groups = 'drop')
  
  no_tree_segments <- df %>%
    filter(!is_tree_segment) %>%
    group_by(segment_id) %>%
    summarize(avg_pm_10_no_tree = mean(pm_10, na.rm = TRUE), .groups = 'drop')
  
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
  
  # Join with the no-tree segments to get their pm_10 averages
  comparison_data <- tree_groups %>%
    left_join(no_tree_segments, by = c("previous_no_tree_segment" = "segment_id"), suffix = c("_tree", "_prev_no_tree")) %>%
    left_join(no_tree_segments, by = c("next_no_tree_segment" = "segment_id"), suffix = c("", "_next_no_tree"))
  
  return(comparison_data)
}

# Apply the function to the data
comparison_data <- find_nearest_no_tree(data)

# Rename columns to align with expected column names for statistical tests
comparison_data <- comparison_data %>%
  rename(
    avg_pm_10_prev_no_tree = avg_pm_10_no_tree,
    avg_pm_10_next_no_tree = avg_pm_10_no_tree_next_no_tree
  )

# Check the comparison data
print(comparison_data)

# Extract unique species for statistical analysis
unique_species <- unique(comparison_data$tree_name)

# Initialize an empty list to store test results
test_results <- list()

# Loop over each unique species
for (species in unique_species) {
  # Filter data for the current species
  species_data <- comparison_data %>%
    filter(tree_name == species)
  
  # Check if there are enough observations to perform the t-tests
  if (nrow(species_data) >= 2) {
    # Perform paired t-test comparing pm_10 levels under trees with the nearest previous no-tree segments
    if (!any(is.na(species_data$avg_pm_10_prev_no_tree))) {
      t_test_result_prev <- t.test(
        species_data$avg_pm_10_tree, 
        species_data$avg_pm_10_prev_no_tree, 
        paired = TRUE, 
        alternative = "two.sided"
      )
    } else {
      t_test_result_prev <- list(statistic = NA, p.value = NA)
    }
    
    # Perform paired t-test comparing pm_10 levels under trees with the nearest next no-tree segments
    if (!any(is.na(species_data$avg_pm_10_next_no_tree))) {
      t_test_result_next <- t.test(
        species_data$avg_pm_10_tree, 
        species_data$avg_pm_10_next_no_tree, 
        paired = TRUE, 
        alternative = "two.sided"
      )
    } else {
      t_test_result_next <- list(statistic = NA, p.value = NA)
    }
    
    # Store the results in the list
    test_results[[species]] <- list(
      species = species,
      t_test_prev = t_test_result_prev,
      t_test_next = t_test_result_next
    )
  } else {
    # Print a message or take action if there are not enough observations
    cat("Not enough observations for species:", species, "\n")
  }
}

# Print the t-test results for each species
for (species in names(test_results)) {
  cat("\nSpecies:", species, "\n")
  cat("Comparison with Previous No-Tree Segment:\n")
  print(test_results[[species]]$t_test_prev)
  cat("\nComparison with Next No-Tree Segment:\n")
  print(test_results[[species]]$t_test_next)
}


# Step 5: Visualize the Comparison for Each Species
# Example visualization for one species (e.g., "Plane")
species_to_visualize <- "Plane"  # Change this to any species you want to visualize

species_data <- comparison_data %>%
  filter(tree_name == species_to_visualize)

if (nrow(species_data) > 0) {
  ggplot(species_data, aes(x = group_id)) +
    geom_point(aes(y = avg_pm_10_tree), color = "green", size = 3, alpha = 0.6) +
    geom_point(aes(y = avg_pm_10_prev_no_tree), color = "red", size = 3, alpha = 0.6) +
    geom_point(aes(y = avg_pm_10_next_no_tree), color = "orange", size = 3, alpha = 0.6) +
    geom_line(aes(y = avg_pm_10_tree), color = "green", linetype = "dashed") +
    geom_line(aes(y = avg_pm_10_prev_no_tree), color = "red", linetype = "dashed") +
    geom_line(aes(y = avg_pm_10_next_no_tree), color = "orange", linetype = "dashed") +
    theme_minimal() +
    labs(title = paste("Comparison of PM10 Levels for", species_to_visualize, "Segments"),
         x = "Group ID",
         y = "Average PM10 Levels") +
    scale_x_continuous(breaks = species_data$group_id) +
    scale_y_continuous(limits = c(min(species_data$avg_pm_10_tree, species_data$avg_pm_10_prev_no_tree, species_data$avg_pm_10_next_no_tree, na.rm = TRUE),
                                  max(species_data$avg_pm_10_tree, species_data$avg_pm_10_prev_no_tree, species_data$avg_pm_10_next_no_tree, na.rm = TRUE)))
}
