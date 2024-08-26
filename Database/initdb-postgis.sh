#!/bin/bash

set -e

# Perform all actions as $POSTGRES_USER
export PGUSER="$POSTGRES_USER"

# Create the 'template_postgis' template db
psql <<- 'EOSQL'
CREATE DATABASE template_postgis IS_TEMPLATE true;
EOSQL

# Load PostGIS into both template_database and $POSTGRES_DB
for DB in template_postgis "$POSTGRES_DB"; do
	echo "Loading PostGIS extensions into $DB"
	psql --dbname="$DB" <<-'EOSQL'
		CREATE EXTENSION IF NOT EXISTS postgis;
		CREATE EXTENSION IF NOT EXISTS postgis_topology;
		-- Reconnect to update pg_setting.resetval
		-- See https://github.com/postgis/docker-postgis/issues/288
		\c
		CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
		CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;
EOSQL
done

echo "create tables for" "$POSTGRES_DB"
#cretae tables for airquality_db database
psql --dbname="$POSTGRES_DB" <<-'EOSQL'
create schema sensor;
create schema import;
create table sensor.dist_5
(
    id                           serial
        primary key,
    time                         text,
    location                     text,
    pm_1                         double precision,
    pm_25                        double precision,
    pm_10                        double precision,
    pm_4                         double precision,
    temperature                  double precision,
    humidity                     double precision,
    pressure                     double precision,
    temperature2                 double precision,
    sensor_geom                  geometry(Point, 4326),
    elevation                    double precision,
    dist_to_closest_tree         double precision,
    air_measurement              double precision,
    tree_number_x                integer,
    air_tree_id                  text,
    distance_to_tree             double precision,
    objectid                     integer,
    tree_geom                    geometry(Point, 4326),
    tree_within_d20              boolean,
    borough                      text,
    gla_tree_group               text,
    tree_name                    text,
    taxon_name                   text,
    age                          text,
    age_group                    text,
    spread_m                     double precision,
    height_m                     double precision,
    diameter_at_breast_height_cm double precision,
    gdb_geomattr_data            double precision,
    load_date                    timestamp,
    updated                      timestamp
);

alter table sensor.dist_5
    owner to postgres;

create index sensor_loc5index
    on sensor.dist_5 using gist (sensor_geom);

create index tree_loc5_index
    on sensor.dist_5 using gist (tree_geom);

create index idx_loc5
    on sensor.dist_5 (location);

create table sensor.dist_15
(
    id                           serial
        primary key,
    time                         text,
    location                     text,
    pm_1                         double precision,
    pm_25                        double precision,
    pm_10                        double precision,
    pm_4                         double precision,
    temperature                  double precision,
    humidity                     double precision,
    pressure                     double precision,
    temperature2                 double precision,
    sensor_geom                  geometry(Point, 4326),
    elevation                    double precision,
    dist_to_closest_tree         double precision,
    air_measurement              double precision,
    tree_number_x                integer,
    air_tree_id                  text,
    distance_to_tree             double precision,
    objectid                     integer,
    tree_geom                    geometry(Point, 4326),
    tree_within_d20              boolean,
    borough                      text,
    gla_tree_group               text,
    tree_name                    text,
    taxon_name                   text,
    age                          text,
    age_group                    text,
    spread_m                     double precision,
    height_m                     double precision,
    diameter_at_breast_height_cm double precision,
    gdb_geomattr_data            double precision,
    load_date                    timestamp,
    updated                      timestamp
);

alter table sensor.dist_15
    owner to postgres;

create index sensor_loc15index
    on sensor.dist_15 using gist (sensor_geom);

create index tree_loc15_index
    on sensor.dist_15 using gist (tree_geom);

create index idx_loc15
    on sensor.dist_15(location);

create table sensor.dist_10
(
    id                           serial
        primary key,
    time                         text,
    location                     text,
    pm_1                         double precision,
    pm_25                        double precision,
    pm_10                        double precision,
    pm_4                         double precision,
    temperature                  double precision,
    humidity                     double precision,
    pressure                     double precision,
    temperature2                 double precision,
    sensor_geom                  geometry(Point, 4326),
    elevation                    double precision,
    dist_to_closest_tree         double precision,
    air_measurement              double precision,
    tree_number_x                integer,
    air_tree_id                  text,
    distance_to_tree             double precision,
    objectid                     integer,
    tree_geom                    geometry(Point, 4326),
    tree_within_d20              boolean,
    borough                      text,
    gla_tree_group               text,
    tree_name                    text,
    taxon_name                   text,
    age                          text,
    age_group                    text,
    spread_m                     double precision,
    height_m                     double precision,
    diameter_at_breast_height_cm double precision,
    gdb_geomattr_data            double precision,
    load_date                    timestamp,
    updated                      timestamp
);

alter table sensor.dist_10
    owner to postgres;

create index sensor_loc10index
    on sensor.dist_10 using gist (sensor_geom);

create index tree_loc10_index
    on sensor.dist_10 using gist (tree_geom);

create index idx_loc10
    on sensor.dist_10(location);

create table sensor.dist_20
(
    id                           serial
        primary key,
    time                         text,
    location                     text,
    pm_1                         double precision,
    pm_25                        double precision,
    pm_10                        double precision,
    pm_4                         double precision,
    temperature                  double precision,
    humidity                     double precision,
    pressure                     double precision,
    temperature2                 double precision,
    sensor_geom                  geometry(Point, 4326),
    elevation                    double precision,
    dist_to_closest_tree         double precision,
    air_measurement              double precision,
    tree_number_x                integer,
    air_tree_id                  text,
    distance_to_tree             double precision,
    objectid                     integer,
    tree_geom                    geometry(Point, 4326),
    tree_within_d20              boolean,
    borough                      text,
    gla_tree_group               text,
    tree_name                    text,
    taxon_name                   text,
    age                          text,
    age_group                    text,
    spread_m                     double precision,
    height_m                     double precision,
    diameter_at_breast_height_cm double precision,
    gdb_geomattr_data            double precision,
    load_date                    timestamp,
    updated                      timestamp
);

alter table sensor.dist_20
    owner to postgres;

create index sensor_loc20index
    on sensor.dist_20 using gist (sensor_geom);

create index tree_loc20_index
    on sensor.dist_20 using gist (tree_geom);

create index idx_loc20
    on sensor.dist_20 (location);

create table sensor.dist_50
(
    id                           serial
        primary key,
    time                         text,
    location                     text,
    pm_1                         double precision,
    pm_25                        double precision,
    pm_10                        double precision,
    pm_4                         double precision,
    temperature                  double precision,
    humidity                     double precision,
    pressure                     double precision,
    temperature2                 double precision,
    sensor_geom                  geometry(Point, 4326),
    elevation                    double precision,
    dist_to_closest_tree         double precision,
    air_measurement              double precision,
    tree_number_x                integer,
    air_tree_id                  text,
    distance_to_tree             double precision,
    objectid                     integer,
    tree_geom                    geometry(Point, 4326),
    tree_within_d20              boolean,
    borough                      text,
    gla_tree_group               text,
    tree_name                    text,
    taxon_name                   text,
    age                          text,
    age_group                    text,
    spread_m                     double precision,
    height_m                     double precision,
    diameter_at_breast_height_cm double precision,
    gdb_geomattr_data            double precision,
    load_date                    timestamp,
    updated                      timestamp
);

alter table sensor.dist_50
    owner to postgres;

create index sensor_loc50index
    on sensor.dist_50 using gist (sensor_geom);

create index tree_loc50_index
    on sensor.dist_50 using gist (tree_geom);

create index idx_loc50
    on sensor.dist_50 (location);

create table sensor.dist_100
(
    id                           serial
        primary key,
    time                         text,
    location                     text,
    pm_1                         double precision,
    pm_25                        double precision,
    pm_10                        double precision,
    pm_4                         double precision,
    temperature                  double precision,
    humidity                     double precision,
    pressure                     double precision,
    temperature2                 double precision,
    sensor_geom                  geometry(Point, 4326),
    elevation                    double precision,
    dist_to_closest_tree         double precision,
    air_measurement              double precision,
    tree_number_x                integer,
    air_tree_id                  text,
    distance_to_tree             double precision,
    objectid                     integer,
    tree_geom                    geometry(Point, 4326),
    tree_within_d20              boolean,
    borough                      text,
    gla_tree_group               text,
    tree_name                    text,
    taxon_name                   text,
    age                          text,
    age_group                    text,
    spread_m                     double precision,
    height_m                     double precision,
    diameter_at_breast_height_cm double precision,
    gdb_geomattr_data            double precision,
    load_date                    timestamp,
    updated                      timestamp
);

alter table sensor.dist_100
    owner to postgres;

create index sensor_loc100index
    on sensor.dist_100 using gist (sensor_geom);

create index tree_loc100_index
    on sensor.dist_100 using gist (tree_geom);

create index idx_loc100
    on sensor.dist_100(location);


EOSQL

