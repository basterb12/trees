# Tree airquality
## 1. Data Processing:
**How to run data processing for Measurements from Atmotube and gps.**

### On phone (iPhone12):
Atmotube Pro: (1) Start Atmotube Pro (40min warmup) - (2) disconnect from Atmotube app (Settings-device-unpair) - (3) find and connect Atmotube in “nRF Connect” app by Nordic - (4) Activate all available downloads from client (nrF Connect-connect ATMOTUBE-client-select all download icons) - (5) export data (ATMOTUBE-log-share).

### GPS: 
Trip Logger Remote (by Frank Dean) - (1) Settings-Local logging-period:1sec, distance:none, enabled; Accuracy:best, minimumHDOP:5metres, seektime:none, max activity history:1,000(max) - (2) Start - (3) Stop - (4) Tracks-select-share.


### On computer 
(macOS Sonoma 14.4.1: Python 3.11.5 using Jupyter Notebook 6.5.4 in Anaconda 2.6.0):

(1) Rename input file from sensor data adding 'YYYY-MM-DD_LL_'* to 'OG-FILENAME.txt'.
*LL is a 2 character site classifier
Sites are: LL - Lewisham-Lewisham; NC - New Cross; A2 - Southwark Old Kent Road (A2); ST - Sydenham testing; CM - Camden

Requirements: requires scripts ‘import.config.json’ , ‘import_data.py’ , ‘sensor_file_parser.py’ , ‘sens.tree.comb.py’.

(2) import.config.json : specify input and desired output file paths.
(3) sens.tree.comb.py : specify input sensor and gpx files (line 37-39).

In console: (1) navigate to directory containing scripts - (2) python import_data.py INPUT_FILENAME.TXT - (3) python sens.tree.comb.py.

Outputs: (1) ‘DATE_interp_sensor_gpx.csv’ (in Output/Output - air_location), (2) 'DATE_air_tree_matched.csv' (in Output/Output - air_tree_distance), (3) 'DATE_[TREESINRADIUS]_all_air_tree_data.csv' (in Output/Output - all_air_location_tree) created in specified output directory. 

Files contain (1) matched sensor and gpx data; (2) sens+gpx data mached with tree database; (3) sens+gpx+trees including distances to trees and tree characteristics. 

Only output (3) is used in analysis. Other files (1 and 2) are created for possible data inspection. Files are created that match trees and air measurements. Separate files are created for matches within 5, 10, 15, 20, and 50 metres.


## 2. Database

### Installation
Using docker: Install docker dektop with docker compose (on Mac) https://docs.docker.com/desktop/install/mac-install/ or docker-ce on Linux.
In order to work with the database there are apps which can be installed: https://postgresapp.com/documentation/gui-tools.html.

### Build container and database

cd in the Database folder on repository and run:
```
docker build . -t dbtrees:latest
````
### Configure and start container

The container configuration is defined in a docker-compose.yaml file. Example setup files are given in Database folder in repository including the data structure in 'initdb-postgis.sh' and packages and updates in the 'Dockerfile'.

If a volume is specified in the docker compose file, it must be created on the host and must be empty.
Change the maintainer in the 'Dockerfile' to set up the database. 

The container can be started with:
```bash
docker compose -p airquality up -d

docker exec -it airquality-geodb14-1 psql -U postgres -d airquality_db

```
From the host the database can be reached by host=loaclahost and port=5439.


### Load data into the database
Run 'load_data.py' script from console. Can be found in 'Data processing' folder on repository. This adds any files from Output/Output - air_tree_distance folder into database (Output (3) from Data processing).

### Run analysis
Analysis scripts can be found in repository folder 'Data analysis'. Warning: To perform the data analysis for separate sites, times, or to select values from parks/street areas the query function might have to be adjusted within the analysis scripts.

(1) To perform paired t-test of segments near trees and the next closest non-tree segments run 't-test_tree_no_tree.R'. This includes a gam for analysing tree dbh impact on difference in pollution and temperature near trees.

(2) To perform comparison of temperature and PM measurements in parks and outside of parks run 'park_no_park.R'.

(3) For additional visualisations run 'visualisation.R'.


