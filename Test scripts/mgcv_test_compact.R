# Load necessary libraries
library(mgcv)
library(dplyr)
library(ggplot2)
library(readr)



# Load the data
data <- read_csv("/Users/sebastianherbst/Dissertation/Data processing/Output/Output - all_air_location_tree/2024-06-17-LL_50m_all_air_tree_data.csv")



#Prepare data
# Convert 'tree_name' and 'age' to factors if they are not already
data$tree_name <- as.factor(data$tree_name)
data$age <- as.factor(data$age)

# Check for missing values in columns of interest
sapply(data[c("Distance_to_tree", "tree_name", "age", "pm_25")], function(x) sum(is.na(x)))

# Filter data to include only rows with no missing values in relevant columns
complete_data <- data %>%
  filter(!is.na(Distance_to_tree) & !is.na(tree_name) & !is.na(age))



#Create plots of data
# Scatter plot of air quality vs distance to the nearest tree
plot_air_dist <- ggplot(complete_data, aes(x=Distance_to_tree, y=pm_25)) +
  geom_point() +
  theme_minimal() +
  labs(title="Air Quality v Distance to Nearest Tree",
       x="Distance to Nearest Tree (meters)",
       y="Air Quality Measure")
ggsave("/Users/sebastianherbst/Dissertation/Data processing/Test scripts/Test output/air_quality_v_distance.png", plot = plot_air_dist, width = 8, height = 6, dpi = 300)

# Boxplot of air quality by tree name
plot_air_species <- ggplot(complete_data, aes(x=tree_name, y=pm_25)) +
  geom_boxplot() +
  theme_minimal() +
  labs(title="Air Quality by Tree Name",
       x="Tree Name",
       y="Air Quality Measure") +
  theme(axis.text.x = element_text(angle=45, hjust=1))
ggsave("/Users/sebastianherbst/Dissertation/Data processing/Test scripts/Test output/air_quality_by_species.png", plot = plot_air_species, width = 8, height = 6, dpi = 300)



#Set up GAM model to show impact of distance to tree, species, age
# Fit the GAM model with the updated column name and complete data
gam_model <- gam(pm_25 ~ s(Distance_to_tree) + tree_name, data=complete_data)

# Summary of the model
summary(gam_model)



##Verify the mgcv GAM model output

##Compare predicted and measured values
# Generate predicted values
predicted_values <- predict(gam_model, newdata=complete_data)

# Combine actual and predicted values into a new DataFrame
results <- complete_data %>%
  mutate(predicted_pm_25 = predicted_values)

# Align predictions with the original data
# Map the predicted values back to the original data
data$predicted_pm_25 <- NA
data$predicted_pm_25[complete.cases(data[c("Distance_to_tree", "tree_name", "age")])] <- predicted_values

# Plot Actual vs Predicted values using the combined DataFrame
plot_act_pred <- ggplot(results, aes(x=pm_25, y=predicted_pm_25)) +
  geom_point() +
  geom_abline(slope=1, intercept=0, color="red") +
  theme_minimal() +
  labs(title="Predicted vs. Actual Air Quality",
       x="Actual Air Quality (pm_25)",
       y="Predicted Air Quality (pm_25)")
ggsave("/Users/sebastianherbst/Dissertation/Data processing/Test scripts/Test output/actual_v_pred_values.png", plot = plot_act_pred, width = 8, height = 6, dpi = 300)



## Show impact of each individual variable
# Set up the plotting area to show multiple plots in one figure
par(mfrow = c(2, 2))

# Plot diagnostic plots for the GAM model
#Plot distance v pollution
# Assuming you have already created the plot using plot()
plot_dist_pol <- plot(gam_model, residuals = TRUE, pch = 16, cex = 0.6)
png("/Users/sebastianherbst/Dissertation/Data processing/Test scripts/Test output/plot_dist_pol.png", width = 800, height = 600, units = "px", res = 300) #save plot
dev.off()

# Reset the plotting layout
par(mfrow = c(1, 1))

# Plot the smooth terms and categorical effects - shows how each predictor affects the response variable
plot(gam_model, pages = 1, all.terms = TRUE, shade = TRUE)



##Compute residuals from the GAM model - patterns in residuals can indicate poor fit
residuals <- residuals(gam_model)

# Add residuals to the results data frame
results <- results %>%
  mutate(residuals = residuals)

# Plot residuals vs fitted values
plot_res_fit <- ggplot(results, aes(x = predicted_pm_25, y = residuals)) +
  geom_point() +
  geom_hline(yintercept = 0, color = "red") +
  theme_minimal() +
  labs(title = "Residuals vs. Fitted Values",
       x = "Predicted Air Quality (pm_25)",
       y = "Residuals")
ggsave("/Users/sebastianherbst/Dissertation/Data processing/Test scripts/Test output/residuals.png", plot = plot_res_fit, width = 8, height = 6, dpi = 300)
