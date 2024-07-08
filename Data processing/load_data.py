# Library
import psycopg2
import re
import json
from pathlib import Path
import pandas as pd
from sqlalchemy import create_engine, text, exc

# Load the database connection parameters
with open("import.config.json", "r") as jsonfile:
    import_config = json.load(jsonfile)

# Create a connection to the PostgreSQL server
conn = psycopg2.connect(
    host=import_config['host'],
    database=import_config['database'],
    user=import_config['user'],
    password=import_config['password'],
    port=import_config['port']
)

# Create a cursor object
cur = conn.cursor()

# Set automatic commit to be true, so that each action is committed without having to call conn.committ() after each command
conn.set_session(autocommit=True)

# Commit the changes and close the connection to the default database
# Connect to the 'soccer' database

engine = create_engine(f'postgresql://{import_config["user"]}:{import_config["password"]}@{import_config["host"]}:{import_config["port"]}/{import_config["database"]}')

# Define the file paths for your CSV files
for path in Path(import_config["sens_gpx_tree_path"]).resolve().iterdir():
    location = path.name[11:13]
    dist = re.search(r'\d+', path.name[14:16]).group()
    print(f'Import: {path.name} -> {path.name.rfind("_")} {location} {dist} m')
    df = pd.read_csv(path)
    fname  = path.name.rstrip(".csv")
    try:
        df.to_sql(fname, engine, if_exists='replace', index=False, schema='import')
        cur.execute(f'insert into sensor.dist_{dist} ("time", location, pm_1, pm_25, pm_10, pm_4, temperature, '
                    f'humidity, pressure, temperature2, sensor_geom, elevation, dist_to_closest_tree, air_measurement, '
                    f'tree_number_x, air_tree_id, distance_to_tree, objectid, tree_geom, tree_within_d20, borough, '
                    f'gla_tree_group, tree_name, taxon_name, age, age_group, spread_m, height_m, diameter_at_breast_height_cm, '
                    f'gdb_geomattr_data, updated) select time, \'{location}\', pm_1, pm_25, pm_10, pm_4, temperature, humidity, pressure, temperature2, '
                    f'st_setsrid(st_makepoint(longitude,latitude),4326), elevation, "Dist_to_closest_tree", "Air measurement", '
                    f'"Tree number_x", "Air-tree ID", "Distance_to_tree", objectid, st_setsrid(st_makepoint(lon,lat),4326), '
                    f'"Tree_within_d_(default: 20m)", borough, gla_tree_group, tree_name, taxon_name, age, age_group, spread_m, '
                    f'height_m, diameter_at_breast_height_cm, gdb_geomattr_data, now()'
                    f' from import."{fname}" i where not exists(select 1 from sensor.dist_{dist} where dist_{dist}.time = i.time '
                    f'and st_equals(sensor_geom, st_setsrid(st_makepoint(longitude,latitude),4326)) );')
        conn.commit()
    except  Exception as e:
        print(f'Error during import ---> {e} {path}')
        pass

cur.close()
conn.close()
