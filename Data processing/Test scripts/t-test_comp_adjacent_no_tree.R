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

# Check the data with segment identifiers
head(data)

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
    group_by(group_id) %>%
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

# Check the comparison data
print(comparison_data)

# Rename columns to align with expected column names for statistical tests
comparison_data <- comparison_data %>%
  rename(
    avg_pm_10_prev_no_tree = avg_pm_10_no_tree,
    avg_pm_10_next_no_tree = avg_pm_10_no_tree_next_no_tree
  )

# Step 4: Perform Statistical Analysis
# Check if the columns avg_pm_10_prev_no_tree and avg_pm_10_next_no_tree exist and have data
if (!"avg_pm_10_prev_no_tree" %in% colnames(comparison_data)) {
  stop("Column 'avg_pm_10_prev_no_tree' does not exist in the comparison data.")
}

if (!"avg_pm_10_next_no_tree" %in% colnames(comparison_data)) {
  stop("Column 'avg_pm_10_next_no_tree' does not exist in the comparison data.")
}

# Check if the columns have enough non-NA values
if (sum(!is.na(comparison_data$avg_pm_10_prev_no_tree)) < 2) {
  stop("Not enough non-NA observations in 'avg_pm_10_prev_no_tree' for statistical test.")
}

if (sum(!is.na(comparison_data$avg_pm_10_next_no_tree)) < 2) {
  stop("Not enough non-NA observations in 'avg_pm_10_next_no_tree' for statistical test.")
}

# Paired t-test comparing pm_10 levels under trees with the nearest previous no-tree segments
t_test_result_prev <- t.test(
  comparison_data$avg_pm_10_tree, 
  comparison_data$avg_pm_10_prev_no_tree, 
  paired = TRUE, 
  alternative = "two.sided"
)

# Print the t-test result for previous no-tree segment
print(t_test_result_prev)

# Paired t-test comparing pm_10 levels under trees with the nearest next no-tree segments
t_test_result_next <- t.test(
  comparison_data$avg_pm_10_tree, 
  comparison_data$avg_pm_10_next_no_tree, 
  paired = TRUE, 
  alternative = "two.sided"
)

# Print the t-test result for next no-tree segment
print(t_test_result_next)

# Step 5: Visualize the Comparison
# Visualize the comparison using ggplot2
ggplot(comparison_data, aes(x = group_id)) +
  geom_point(aes(y = avg_pm_10_tree), color = "blue", size = 3, alpha = 0.6) +
  geom_point(aes(y = avg_pm_10_prev_no_tree), color = "red", size = 3, alpha = 0.6) +
  geom_point(aes(y = avg_pm_10_next_no_tree), color = "red", size = 3, alpha = 0.6) +
  geom_line(aes(y = avg_pm_10_tree), color = "blue", linetype = "dashed") +
  geom_line(aes(y = avg_pm_10_prev_no_tree), color = "red", linetype = "dashed") +
  geom_line(aes(y = avg_pm_10_next_no_tree), color = "red", linetype = "dashed") +
  theme_minimal() +
  labs(title = "Comparison of PM10 Levels Between Tree and Nearest No-Tree Segments",
       x = "Group ID",
       y = "Average PM10 Levels") +
  scale_x_continuous(breaks = comparison_data$group_id) +
  scale_y_continuous(limits = c(min(comparison_data$avg_pm_10_tree, comparison_data$avg_pm_10_prev_no_tree, comparison_data$avg_pm_10_next_no_tree, na.rm = TRUE),
                                max(comparison_data$avg_pm_10_tree, comparison_data$avg_pm_10_prev_no_tree, comparison_data$avg_pm_10_next_no_tree, na.rm = TRUE)))



