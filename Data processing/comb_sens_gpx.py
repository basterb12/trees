#!/usr/bin/env python
# coding: utf-8

# In[1]:

#IMPORTANT: SPECIFY INPUT FILES (LINE 37-39)

#Script takes csv outputs created by "import_data.py" for "Atmotube Pro" data intercepted by "nRF Connect"
#bluetooth API. This data was decoded with "sensor_file_parser.py".
#Then reads gpx data from "TripLogger" mobile app and creates combined pandas dataframe for all sensor and gpx data.

#Long/lat/elevation data is not available for all "time" values, missing data provided using linear 
#interpolation. Location data is only interpolated for up to 5 values between measured points.
#Metereological measurements are taken less frequently by Atmotube Pro - missing data is also interpolated 
#(up to 10 missing values between measurements, linear).

#Final dataframe exported to csv file - one version without ("sensor_gpx_path"), 
#and one with interpolated values ("interp_sensor_gpx_path").



# In[2]:


#imports libraries
import json
import pandas as pd
import gpxpy
import gpxpy.gpx
from datetime import datetime, timedelta



# In[3]:


#input files - need to be specified before run
sensor_file = '2024-05-27_LL_text-CEB3F4AF1F9B-1.txt'
gpx_file = '2024-05-27_LL_triplogger-track-20240527T124039+0100.gpx'

#data path specified in import.config.json
with open("import.config.json", "r") as jsonfile:
    import_config = json.load(jsonfile)

env_data_path = import_config["cache_path"] + sensor_file[:-4] + '_env.csv'
meteo_data_path = import_config["cache_path"] + sensor_file[:-4] + '_meteo.csv'
gpx_file_path = import_config["gpx_path"] + gpx_file

#specify output files
sensor_gpx_path = import_config["sens_gpx_path"] + sensor_file[:13] + '_sensor_gpx.csv'
interp_sensor_gpx_path = import_config["sens_gpx_path"] + sensor_file[:13] + '_interp_sensor_gpx.csv'



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

df_sens_gpx.to_csv(sensor_gpx_path) #creates csv with only measured points (no interpolation)

#interpolate missing lon/lat/elevation data in gpx files
lat_gpx = df_sens_gpx['latitude']
df_sens_gpx['latitude'] = lat_gpx.interpolate(method='linear', axis=0, limit=5, inplace=False, limit_area='inside')
long_gpx = df_sens_gpx['longitude']
df_sens_gpx['longitude'] = long_gpx.interpolate(method='linear', axis=0, limit=5, inplace=False, limit_area='inside')
ele_gpx = df_sens_gpx['elevation']
df_sens_gpx['elevation'] = ele_gpx.interpolate(method='linear', axis=0, limit=5, inplace=False, limit_area='inside')
#interpolate missing meteo data
temp_meteo = df_sens_gpx['temperature']
df_sens_gpx['temperature'] = temp_meteo.interpolate(method='linear', axis=0, limit=10, inplace=False, limit_area='inside')
hum_meteo = df_sens_gpx['humidity']
df_sens_gpx['humidity'] = hum_meteo.interpolate(method='linear', axis=0, limit=10, inplace=False, limit_area='inside')
press_meteo = df_sens_gpx['pressure']
df_sens_gpx['pressure'] = press_meteo.interpolate(method='linear', axis=0, limit=10, inplace=False, limit_area='inside')
temp2_meteo = df_sens_gpx['temperature2']
df_sens_gpx['temperature2'] = temp2_meteo.interpolate(method='linear', axis=0, limit=10, inplace=False, limit_area='inside')


df_sens_gpx.to_csv(interp_sensor_gpx_path) #creates csv including interpolated values




