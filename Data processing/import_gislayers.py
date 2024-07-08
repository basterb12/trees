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
for path in Path(import_config["gis_path"]).resolve().iterdir():
    print(f'Import: {path.name}')
    df = pd.read_csv(path)
    fname  = path.name.rstrip(".csv")
    try:
        df.to_sql(fname, engine, if_exists='replace', index=False, schema='import')

        conn.commit()
    except  Exception as e:
        print(f'Error during import ---> {e} {path}')
        pass

cur.close()
conn.close()