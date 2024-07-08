# Tree airquality
## 1. Data Processing:
**How to run data processing for Measurements from Atmotube and gps.**

### On phone (iPhone12):
Atmotube Pro: (1) Start Atmotube Pro (40min warmup) - (2) disconnect from Atmotube app (Settings-device-unpair) - (3) find and connect Atmotube in “nRF Connect” app by Nordic - (4) Activate all available downloads from client (nrF Connect-connect ATMOTUBE-client-select all download icons) - (5) export data (ATMOTUBE-log-share).

### GPS: 
Trip Logger Remote (by Frank Dean) - (1) Settings-Local logging-period:1sec, distance:none, enabled; Accuracy:best, minimumHDOP:5metres, seektime:none, max activity history:1,000(max) - (2) Start - (3) Stop - (4) Tracks-select-share.


### On computer (macOS Sonoma 14.4.1: 
Python 3.11.5 using Jupyter Notebook 6.5.4 in Anaconda 2.6.0):

(1) Rename input file from sensor data adding 'YYYY-MM-DD_LL_'* to 'OG-FILENAME.txt'.
*LL is a 2 character site classifier
Sites are: LL - Lewisham-Lewisham; NC - New Cross; A2 - Southwark Old Kent Road (A2); ST - Sydenham testing; CM - Camden

Requirements: requires scripts ‘import.config.json’ , ‘import_data.py’ , ‘sensor_file_parser.py’ , ‘sens.tree.comb.py’.

(2) import.config.json : specify input and desired output file paths.
(3) sens.tree.comb.py : specify input sensor and gpx files (line 37-39).

In console: (1) navigate to directory containing scripts - (2) python import_data.py INPUT_FILENAME.TXT - (3) python sens.tree.comb.py
.
Outputs: (1) ‘DATE_interp_sensor_gpx.csv’ (in Output/Output - air_location), (2) 'DATE_air_tree_matched.csv' (in Output/Output - air_tree_distance), (3) 'DATE_[TREESINRADIUS]_all_air_tree_data.csv' (in Output/Output - all_air_location_tree)
created in specified output directory. Files contain (1) matched sensor and gpx data; (2) sens+gpx data mached with tree database; (3) sens+gpx+trees including distances to trees and tree characteristics.

T-test using R for adjacent tree, non-tree air quality relationships in 'Data processing' folder as 't_test_by_species.R'
Test R Scripts for data analysis using a GAM in mgcv are located in 'Test scripts' folder. Still being worked on.

## 2. Database

### Installation
Using docker: Install docker dektop with docker compose (on Mac) or docker-ce on Linux.
In order to work with the database there are apps which can be installed: https://postgresapp.com/documentation/gui-tools.html.

### Build container and database

cd in the Database folder on repository and run:
```
docker build . -t dbtrees:latest
````
### Configure and start container

The container configuration is defines in a docker compose file. 

````yaml
version: "2"
services:
  geodb14:
    image: dbtrees:latest
    shm_size: 1g
    ports:
      - 5439:5432
    environment:
      ALLOW_IP_RANGE: 0.0.0.0/0
      POSTGRES_PASSWORD: postgres
      POSTGRES_USER: postgres
      POSTGRES_DB: airquality_db
      POSTGIS_GDAL_ENABLED_DRIVERS: ENABLE_ALL
    volumes:
      - /Users/sebastianherbst/data/dbtrees:/var/lib/postgresql/data
````
If a volume is specified, it must be cerated on the host and must be empty.
The container can be started with:
```bash
docker compose -p airquality up -d
```
From the host the database can be reached by host=loaclahost and port=5439.



