#!/usr/bin/env python
# coding: utf-8

# In[1]:


#IMPORTANT: SPECIFY INPUT FILES (LINE 36-37); CHANGE DISTANCE TO CLOSEST TREE (LINE 33)

#Script takes csv outputs created by "import_data.py" for "Atmotube Pro" data intercepted by "nRF Connect"
#bluetooth API. This data was decoded with "sensor_file_parser.py".
#Then reads gpx data from "TripLogger" mobile app and creates combined pandas dataframe for all sensor and gpx data.

#Long/lat/elevation data is not available for all "time" values, missing data provided using linear 
#interpolation. Location data is only interpolated for up to 10 values between measured points.

#Final dataframe exported to csv file with interpolated values ("interp_sensor_gpx_path").


# In[2]:


#imports libraries
import json
import pandas as pd
import gpxpy
import gpxpy.gpx
import numpy as np
from datetime import datetime, timedelta


# In[3]:


# Variables - set d to find trees and distances within a certain radius of each air measurement - default is set to 20 metres
d = 5

#input files - need to be specified before run
sensor_file = '2024-07-19_A2.txt'
gpx_file = '2024-07-19_A2.gpx'

tree_data_path = '/Users/sebastianherbst/Dissertation/Data processing/Tree data/A2_trees.csv'
tree_data = open(tree_data_path)
df_tree_data = pd.read_csv(tree_data)

#data path specified in import.config.json
with open("import.config.json", "r") as jsonfile:
    import_config = json.load(jsonfile)

env_data_path = import_config["cache_path"] + sensor_file[:-4] + '_env.csv'
meteo_data_path = import_config["cache_path"] + sensor_file[:-4] + '_meteo.csv'
gpx_file_path = import_config["gpx_path"] + gpx_file

#specify output files
sensor_gpx_path = import_config["sens_gpx_path"] + sensor_file[:13] + '_sensor_gpx.csv'
interp_sensor_gpx_path = import_config["sens_gpx_path"] + sensor_file[:13] + '_interp_sensor_gpx.csv'

air_tree_output = import_config["air_tree_path"] + sensor_file[:13] + '_' + str(d) + 'm' +  '_air_tree_matched.csv'
sens_gpx_tree_output = import_config["sens_gpx_tree_path"] + sensor_file[:13] + '_' + str(d) + 'm' + '_all_air_tree_data.csv'


# In[4]:


#create pandas dataframes from decoded sensor measurements (created by import_data.py)
df_env = pd.read_csv(env_data_path)
df_meteo = pd.read_csv(meteo_data_path)

df_env['time'] = pd.to_datetime(df_env['time'], format='ISO8601') # converts to datetime format to match gpx data
df_meteo['time'] = pd.to_datetime(df_meteo['time'], format='ISO8601')

#add env and meteo data into combined pd dataframe
df_sens_comb = pd.merge_ordered(df_env, df_meteo, fill_method="ffill", left_by='time')


# In[5]:


#read gpx data
with open(gpx_file_path, 'r') as f:
    gpx = gpxpy.parse(f)

# Convert to a dataframe one point at a time.
gpx_points = []
for segment in gpx.tracks[0].segments:
    for p in segment.points:
        gpx_points.append({
            'time': p.time,
            'latitude': p.latitude,
            'longitude': p.longitude,
            'elevation': p.elevation,
        })
df_gpx = pd.DataFrame.from_records(gpx_points)

#Remove +00:00 from the end of each timestamp
gpx_time_str = df_gpx['time']
gpx_time_strip = gpx_time_str.astype(str).str.rstrip('+00:00')
df_gpx['time'] = gpx_time_strip
df_gpx['time'] = pd.to_datetime(df_gpx['time'], format='ISO8601')
df_gpx['time'] = df_gpx['time'] + timedelta(hours=1)


# In[6]:


#add dataframes from sensor and gpx into one file - match the time-steps    
df_sens_gpx = pd.merge_ordered(df_sens_comb, df_gpx, fill_method="ffill", left_by='time')

#df_sens_gpx.to_csv(sensor_gpx_path) #creates csv with only measured points (no interpolation)


#interpolate missing lon/lat/elevation data in gpx files
lat_gpx = df_sens_gpx['latitude']
df_sens_gpx['latitude'] = lat_gpx.interpolate(method='linear', axis=0, limit=10, inplace=False, limit_area='inside')
long_gpx = df_sens_gpx['longitude']
df_sens_gpx['longitude'] = long_gpx.interpolate(method='linear', axis=0, limit=10, inplace=False, limit_area='inside')
ele_gpx = df_sens_gpx['elevation']
df_sens_gpx['elevation'] = ele_gpx.interpolate(method='linear', axis=0, limit=10, inplace=False, limit_area='inside')


df_sens_gpx.to_csv(interp_sensor_gpx_path) #creates csv including interpolated values


# In[7]:


df_sens_gpx = df_sens_gpx
df_sens_gpx['latitude'] = df_sens_gpx['latitude'].replace('', np.nan)
df_sens_gpx = df_sens_gpx.dropna(axis=0, subset=['latitude'])

df_sens_gpx_index = np.arange(0,len(df_sens_gpx),1)
df_sens_gpx['Index'] = df_sens_gpx_index


# In[ ]:





# In[8]:


# Second half of script uses sens_gpx output and matches trees to each air pollution measuring point


# In[9]:


#specify the edges of sample area (air measurements plus approx. 100m on each edge)
max_lat = df_sens_gpx['latitude'].max() + 0.001
min_lat = df_sens_gpx['latitude'].min() - 0.001
max_lon = df_sens_gpx['longitude'].max() + 0.0015
min_lon = df_sens_gpx['longitude'].min() - 0.0015


# In[10]:


#Corners of the sample plot = 51.466749,-0.019651; =51.456990,-0.005037

#restrict trees imported to those within a quadrant matching the LL sampling area
df_trees = df_tree_data[(df_tree_data['lat'] >= min_lat) & (df_tree_data['lat'] <= max_lat)]
df_trees = df_trees[(df_trees['lon'] >= min_lon) & (df_trees['lon'] <= max_lon)]

#convert lat long to numpy array
loc_trees_deg = df_trees[['lat','lon']].to_numpy()
loc_air_deg = df_sens_gpx[['latitude','longitude']].to_numpy()


# In[11]:


# Calculates distances between each air measurement point and tree within sample area ##
# Approximate radius of earth in km
R = 6378.1

#convert degrees to radians
loc_air = np.radians(loc_air_deg)
loc_trees = np.radians(loc_trees_deg)

#extract lat long from each array
lat_air, lon_air = loc_air[:,0], loc_air[:,1]
lat_trees, lon_trees = loc_trees[:,0], loc_trees[:,1]

#create pairwise differences
dlat = lat_air[:,np.newaxis] - lat_trees
dlon = lon_air[:,np.newaxis] - lon_trees

#apply haversine formula
a = np.sin(dlat / 2)**2 + np.cos(lat_trees) * np.cos(lat_air[:, np.newaxis]) * np.sin(dlon / 2)**2
c = 2 * np.arcsin(np.sqrt(a))

distances = (R * c) *1000 #'*1000' converts distance from km to m
df_dist = pd.DataFrame(distances)


# In[12]:


#add minimum distance to df_sens_gpx dataframe
min_dist = df_dist.min(axis=1)
df_min_dist = pd.DataFrame(min_dist)
df_min_dist = df_min_dist.rename(columns={0: "Dist_to_closest_tree"})

df_sens_gpx = pd.merge(df_sens_gpx, df_min_dist, left_on='Index', right_index=True)


# In[13]:


#Corners of the sample plot = 51.466749,-0.019651; =51.456990,-0.005037

#restrict trees imported to those within a quadrant matching the LL sampling area
df_trees = df_tree_data[(df_tree_data['lat'] >= min_lat) & (df_tree_data['lat'] <= max_lat)]
df_trees = df_trees[(df_trees['lon'] >= min_lon) & (df_trees['lon'] <= max_lon)]

#convert lat long to numpy array
loc_trees_deg = df_trees[['lat','lon']].to_numpy()
loc_air_deg = df_sens_gpx[['latitude','longitude']].to_numpy()


# In[14]:


#Find trees within d (distance) of air measurements and match distance and tree characteristics to each individual measurement point.
#get trees within d
within_d = distances <= d
tree_within_d = np.where(within_d)
df_tree_within_d = pd.DataFrame(tree_within_d)
df_tree_within_d = df_tree_within_d.transpose()

#isolate the numbers (row number in loc_trees_deg of the trees within d of air measurements)
lat_deg_trees = df_trees[['lat']].to_numpy()
lon_deg_trees = df_trees[['lon']].to_numpy()
mask = np.zeros(lat_deg_trees.shape, dtype=bool)
index_tree_within_d = df_tree_within_d[1].values
mask[index_tree_within_d] = True

#Extract values <= d using the boolean mask
values_within_d = distances[within_d]
#combine values and index into pandas dataframe
index_value = list(zip(index_tree_within_d, values_within_d))
df_index_value = pd.DataFrame(index_value, columns=['Tree number', 'Distance_to_tree'])

#create unique 'Air-tree ID' which matches each measurement with a tree using unique identifier
df_index_value['Air-tree ID'] = df_tree_within_d[0].astype(str) + '_' + df_tree_within_d[1].astype(str)


#add trees within d of air pollution measurement (True in mask)
df_loc_trees = pd.DataFrame(loc_trees_deg)
df_loc_trees['Tree_within_d_(default: 20m)'] = mask

df_loc_trees_index = np.arange(0,len(loc_trees),1)
df_loc_trees['Index (in LL)'] = df_loc_trees_index


# In[15]:


#Merge all outputs into single dataframe and export to csv

#merge each air measurement with the specific tree, its lat/long, and distance to air measurement
df_air_tree = pd.merge(df_tree_within_d, df_loc_trees, left_on=1, right_on='Index (in LL)')
df_air_tree = df_air_tree.rename(columns={'0_x': 'Air measurement', '1_x': 'Tree number', '0_y': 'lat', '1_y': 'lon'})
df_air_tree['Air-tree ID'] = df_air_tree['Air measurement'].astype(str) + '_' + df_air_tree['Tree number'].astype(str) #create unique identifier
df_air_tree = pd.merge(df_air_tree, df_index_value, how='left', on='Air-tree ID')

#match the objectid from london tree database with air measurement values within d 
df_air_tree = pd.merge(df_air_tree, df_tree_data, how='left', on=['lon', 'lat'])
df_air_tree = df_air_tree.sort_values(by=['Air measurement'])

#organise df
df_air_tree = df_air_tree[[1, 'Air measurement', 'Tree number_x', 'Air-tree ID', 'Distance_to_tree', 'objectid', 'lat', 'lon', 'Tree_within_d_(default: 20m)', 'Index (in LL)', 'Tree number_y', 'borough', 'gla_tree_group', 'tree_name', 'taxon_name', 'age', 'age_group', 'spread_m', 'height_m', 'diameter_at_breast_height_cm', 'gdb_geomattr_data', 'load_date', 'updated']]
df_air_tree = df_air_tree.drop([1,'Index (in LL)', 'Tree number_y'], axis=1)

df_air_tree.to_csv(air_tree_output)


# In[16]:


#Add air measurement data to the measurement points used to establish trees within d and distance between trees and air measurements
df_sens_gpx['Index'] = df_sens_gpx['Index'].astype(int)
df_air_tree['Air measurement'] = df_air_tree['Air measurement'].astype(int)
sens_gpx_tree = pd.merge(df_sens_gpx, df_air_tree, how='left', left_on='Index', right_on='Air measurement')
sens_gpx_tree = sens_gpx_tree.drop('Index', axis=1) #clean-up


# In[18]:


#print(sens_gpx_tree)
unique_tree_names = sens_gpx_tree['tree_name'].unique()

# Define the mapping dictionary
tree_name_mapping = {
    'Common Whitebeam': 'Whitebeam',
    'Common Whitebeam ': 'Whitebeam',
    'Swedish Whitebeam ': 'Whitebeam',
    'Common Hornbeam': 'Hornbeam',
    'London Plane': 'Plane',
    'False-acacia': 'False Acacia',
    'Sycamore Maple': 'Sycamore',
    'Snake-Bark Maple': 'Maple',
    'Ashleaf Maple': 'Maple',
    'Silver Maple': 'Maple',
    'Variegated Norway Maple': 'Norway Maple',
    'Purple Norway Maple': 'Norway Maple',
    'Ash': 'Common Ash',
    'Snowy Mespilus': 'Mespilus',
    'Cardinal Royal Rowan ': 'Rowan',
    'Upright Rowan': 'Rowan',
    'Chonosuki Crab': 'Crab Apple',
    'Flowering Crab Apple Rudolph': 'Crab Apple',
    'Ash ': 'Ash',
    'Mountain Ash': 'Ash',
    'Mountain Ash ': 'Ash',
    'Raywood Ash': 'Ash',
    'Raywood Ash ': 'Ash',
    'Common Ash ': 'Ash',
    'Common Ash': 'Ash',
    'Manna Ash': 'Ash',
    'Weeping Ash ': 'Ash',
    'Upright Sargent’s Cherry ': 'Cherry',
    "Cherry 'Pandora'": 'Cherry',
    'Hillieri Spire Cherry': 'Cherry',
    "Rosebud Cherry 'Autumnalis'": 'Cherry',
    'Sweet Cherry': 'Cherry',
    'Tibetan Cherry': 'Cherry',
    'Pink Flowering Cherry': 'Cherry',
    'Cherry ': 'Cherry',
    'Japanese Cherry': 'Cherry',
    "Cherry 'Kanzan'": 'Cherry',
    'Flowering Cherry': 'Cherry',
    'Spring Cherry': 'Cherry',
    "Inermis' Black Locust": 'Black Locust',
    'West Himalayan Birch': 'Birch',
    'Moor Birch': 'Birch',
    "Jacquemont's Birch": 'Birch',
    ' Silver Birch ': 'Birch',
    'Silver Birch': 'Birch',
    'Downy Birch': 'Birch',
    'Paper Birch': 'Birch',
    '‘Edinburgh’ Birch': 'Birch',
    'Common Hawthorn ': 'Hawthorn',
    'Bastard Service Tree ': 'Service Tree',
    'Box Elder': 'Elder',
    'Common Alder': 'Alder',
    'Grey Alder': 'Alder',
    'Red Alder': 'Alder',
    'Common Lime ': 'Lime',
    'Lime Tree': 'Lime',
    'Red Horse-Chestnut': 'Horse-Chestnut',
    'Purple Leaved Plum': 'Plum',
    'Portugal Laurel': 'Laurel',
    'English Yew': 'Yew',
    'Common Lilac': 'Lilac',
    'Common Beech': 'Beech',
    'Purple Beech': 'Beech',
    'Variegated Holly': 'Holly',
    'Common Holly':'Holly',
    'Turkey Oak ': 'Oak',
    'Holly Oak ': 'Oak',
    'English Oak': 'Oak',
    'Black Walnut ': 'Walnut',
    'Hybrid Crack-willow': 'Willow',
    'Giant Fir': 'Fir',
    'Pyrus Species': 'Plum',
    'Wild Plum': 'Plum',
    'Cherry Plum': 'Plum',
    'Linden': 'Lime',
    'A Flowering Plant': 'Shadbush'
    
}

# Apply the mapping to the 'tree_name' column
sens_gpx_tree['tree_name'] = sens_gpx_tree['tree_name'].replace(tree_name_mapping)

#unique_tree_names = sens_gpx_tree['tree_name'].unique()
#print(unique_tree_names)


# In[ ]:


sens_gpx_tree.to_csv(sens_gpx_tree_output) #export as csv


# In[ ]:




