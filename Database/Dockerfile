FROM ghcr.io/gui/postgis:15-postgis-3  as builder

LABEL maintainer= #specify your database maintainer here
ENV PG_MAJOR 15

WORKDIR /

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      autoconf \
      automake \
      autotools-dev \
      bison \
      build-essential \
      ca-certificates \
      cmake \
      g++ \
      git \
      libboost-all-dev \
      libcgal-dev \
      libcurl4-gnutls-dev \
      libgmp-dev \
      libjson-c-dev \
      libmpfr-dev \
      libpcre3-dev \
      libprotobuf-c-dev \
      libsqlite3-dev \
      libtiff-dev \
      libtool \
      libxml2-dev \
      make \
      pkg-config \
      postgresql-server-dev-$PG_MAJOR \
      postgresql-$PG_MAJOR-pldebugger \
      protobuf-c-compiler \
      xsltproc

RUN apt-get install -y r-base-dev
COPY atopkrige_0.4.tar.gz /tmp/atopkrige_0.4.tar.gz
RUN  R -e 'install.packages("sp",dependencies = TRUE,repos="https://cran.uni-muenster.de/")' \
     && R -e 'install.packages("gstat",dependencies = TRUE,repos="https://cran.uni-muenster.de/")' \
     && R -e 'install.packages("rgdal",dependencies = TRUE,repos="https://cran.uni-muenster.de/")' \
     && R -e 'install.packages("dplyr",dependencies = TRUE,repos="https://cran.uni-muenster.de/")' \
     && R -e 'install.packages("readr",dependencies = TRUE,repos="https://cran.uni-muenster.de/")' \
     && R -e 'install.packages("ggplot2",dependencies = TRUE,repos="https://cran.uni-muenster.de/")' \
     && R -e 'install.packages("tidyr",dependencies = TRUE,repos="https://cran.uni-muenster.de/")' \
     && R -e 'install.packages("stringr",dependencies = TRUE,repos="https://cran.uni-muenster.de/")' \
     && R -e 'install.packages("rjson",dependencies = TRUE,repos="https://cran.uni-muenster.de/")' \
     && R -e 'install.packages("/tmp/atopkrige_0.4.tar.gz", dependencies = TRUE, type="source")' \
    &&  git clone https://github.com/postgres-plr/plr \
    && cd plr \
    && USE_PGXS=1 make \
    && USE_PGXS=1 make install      


RUN mkdir -p /docker-entrypoint-initdb.d
COPY ./initdb-postgis.sh /docker-entrypoint-initdb.d/10_postgis.sh
COPY ./update-postgis.sh /usr/local/bin

