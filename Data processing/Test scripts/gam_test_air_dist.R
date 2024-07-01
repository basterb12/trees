# Load necessary libraries
library(mgcv)
library(dplyr)
library(ggplot2)
library(readr)
library(gratia)



# Load the data
data <- read_csv("/Users/sebastianherbst/Dissertation/Data processing/Output/Output - all_air_location_tree/2024-06-28_CM_50m_all_air_tree_data.csv")



# Prepare data
# Convert appropriate columns to factors or numeric
data <- data %>%
  mutate(
    taxon_name = as.factor(taxon_name),
    tree_name = as.factor(tree_name),
    age = as.factor(age),
    Dist_to_closest_tree = as.numeric(Dist_to_closest_tree),
    Distance_to_tree = as.numeric(Distance_to_tree)
  )

# Check for missing values in relevant columns
missing_values <- sapply(data[c("Distance_to_tree", "Dist_to_closest_tree", "taxon_name", "tree_name", "age", "pm_10")], function(x) sum(is.na(x)))
print(missing_values)

# Filter out rows with missing values in critical columns
complete_data <- data %>%
  filter(!is.na(Distance_to_tree) & !is.na(Dist_to_closest_tree) & !is.na(pm_10))

# Check the number of unique values for basis dimension consideration
unique_distance_to_tree <- length(unique(complete_data$Distance_to_tree))
unique_dist_to_closest_tree <- length(unique(complete_data$Dist_to_closest_tree))

# Fit the GAM model with flexible basis dimensions
# Choosing 'k' slightly lower than the number of unique values for stability
k_distance_to_tree <- min(10, unique_distance_to_tree - 1)
k_dist_to_closest_tree <- min(10, unique_dist_to_closest_tree - 1)



#Implement gam model
gam_model_pm_10 <- gam(pm_10 ~ s(Distance_to_tree, k = k_distance_to_tree) + s(Dist_to_closest_tree, k = k_dist_to_closest_tree), 
                       data = complete_data, method = 'REML', select = TRUE)


summary(gam_model_pm_10)

# Create diagnostic plots for the model
par(mfrow = c(2, 2))
gam.check(gam_model_pm_10, rep = 5000)

# Additional model diagnostics
par(mfrow = c(1, 1))
draw(gam_model_pm_10)





# Create a data frame with the fitted values
prediction_data <- data.frame(
  Distance_to_tree = complete_data$Distance_to_tree,
  Fitted = predict(gam_model_pm_10, type = "response"),
  Residuals = residuals(gam_model_pm_10)
)

# Scatter plot with the fitted smooth line
ggplot(prediction_data, aes(x = Distance_to_tree, y = Fitted)) +
  geom_point(aes(y = complete_data$pm_10), alpha = 0.3) +  # Actual data points
  geom_line(color = "blue", size = 1) +  # Fitted smooth line
  theme_minimal() +
  labs(title = "Fitted Smooth Line for Distance to Tree",
       x = "Distance to Nearest Tree (meters)",
       y = "Fitted PM10 Levels")

# Boxplot of air quality by tree name
ggplot(complete_data, aes(x = tree_name, y = pm_10)) +
  geom_boxplot() +
  theme_minimal() +
  labs(title = "Air Quality by Tree Name",
       x = "Tree Name",
       y = "PM 10") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

