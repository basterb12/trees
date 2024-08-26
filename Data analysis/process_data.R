# process data from DB - outliers, missing values, synonymous tree_name values

# Filter out outliers
data <- data %>%
  filter(pm_1 <= 75, pm_25 <= 75, pm_4 <= 75, pm_10 <= 75)


# Replace NaN in tree_name with 'No_tree'
data$tree_name <- as.factor(ifelse(is.na(data$tree_name), "No_tree", as.character(data$tree_name)))

# Create a function to standardise tree names
standardise_tree_name <- function(name) {
  name <- tolower(name)  # Convert to lowercase for uniformity
  name <- trimws(name)  # Remove leading and trailing whitespace

  # Define a mapping of tree names to their standardised names
  tree_name_mapping <- list(
    "fraxinus excelsior" = "ash",
    "common ash" = "ash",
    "maples" = "maple",
    "evergreen oak" = "oak",
    "acorn" = "oak",
    "tree of heaven" = "tree-of-heaven",
    "june berry" = "juneberry",
    "shadbush" = "juneberry",
    "tilia sp." = "lime",
    "deal" = "scots pine",
    "large-leaved lime" = "lime",
    "birch sp." = "birch",
    "oak sp." = "oak",
    "hybrid cockspurthorn" = "cockspurthorn",
    "tulip-tree" = "tulip tree",
    "wild cherry" = "bird cherry",
    "red horse-chestnut" = "horse-chestnut"
  )

  # Standardize the name if it exists in the mapping
  if (name %in% names(tree_name_mapping)) {
    return(tree_name_mapping[[name]])
  } else {
    return(name)  # Return the original name if no mapping is found
  }
}

# Apply the function to the tree_name column
data$tree_name <- sapply(data$tree_name, standardise_tree_name)