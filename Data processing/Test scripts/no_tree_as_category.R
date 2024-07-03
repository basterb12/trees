#compare data with tree to adjacent no_tree measurements

# Load necessary libraries
library(dplyr)
library(ggplot2)
library(mgcv)
library(readr)

# Load the data
data <- read_csv("/Users/sebastianherbst/Dissertation/Data processing/Output/Output - all_air_location_tree/2024-06-28_CM_5m_all_air_tree_data.csv")

# Convert 'tree_name' to a factor, treating 'NaN' appropriately
data$tree_name <- as.factor(ifelse(is.na(data$tree_name), "No_Tree", as.character(data$tree_name)))
#data$tree_name <- if(is(data$tree_name, "Common Whitebeam")), "Whitebeam", as.character(data$tree_name)
# Check the structure of the data
str(data)



# Assuming you have an ID column or coordinates to determine adjacency
# For simplicity, let's assume there is an 'ID' column and use lead/lag to find adjacent rows
data <- data %>%
  mutate(
    adjacent_tree = lead(tree_name) == "No_Tree" | lag(tree_name) == "No_Tree"
  )

# Filter to include only rows where tree_name is 'No_Tree' and adjacent to a tree
adjacent_data <- data %>%
  filter(tree_name == "No_Tree" & adjacent_tree)

# Combine adjacent tree data with data points that have trees
combined_data <- rbind(
  data %>% filter(tree_name != "No_Tree"),
  adjacent_data
)

# Inspect the filtered and combined data
summary(combined_data)




# Fit a GAM model to analyze the relationship
gam_model <- gam(pm_10 ~ tree_name + s(Distance_to_tree) + s(Dist_to_closest_tree), 
                 data = combined_data, method = 'REML', select = TRUE)

# Summary of the model
summary(gam_model)

# Visualization of the effect of 'tree_name' on air quality (pm_10)
# Boxplot for visual comparison
ggplot(combined_data, aes(x = tree_name, y = pm_10)) +
  geom_boxplot() +
  theme_minimal() +
  labs(title = "Air Quality (PM 10) by Tree Presence",
       x = "Tree Presence",
       y = "PM 10 Levels") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# If you want to visualize the smooth effect of distance to the nearest tree
draw(gam_model)

