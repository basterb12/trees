import os
from sys import argv
import pandas
import json
from sensor_file_parser import SensorFileParser


def main(argv):
    sensor_file = argv[1]
    print(f'import {sensor_file}')

    #must specify data path in import.config.json
    with open("import.config.json", "r") as jsonfile:
        import_config = json.load(jsonfile)

    file_name = import_config["data_path"] + sensor_file
    output_name = import_config["cache_path"] + sensor_file

    #logic in class sensorFileParser
    file_parser = SensorFileParser()
    #results are 2 dataframes one for meteo and one for environment
    #fileparser needs full file path and date (from name 0:10)
    results = file_parser.parse_file(file_name, sensor_file[0:10])
    meteo_df:pandas.DataFrame = results[0]
    env_df:pandas.DataFrame = results[1]
    meteo_df.to_csv(output_name[:-4]+'_meteo.csv', index=False)
    env_df.to_csv(output_name[:-4] + '_env.csv', index=False)


if __name__ == "__main__":
    main(argv)