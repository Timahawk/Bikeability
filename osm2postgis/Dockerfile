# The base image we pull.
# We use this because all required gdal libs are already installed.
FROM postgis/postgis

# Update the package lib
RUN apt-get update -y
# Upgrade all packages
RUN apt-get upgrade -y

# Install nessary software
RUN apt install osm2pgsql -y

# Change working directory
WORKDIR "/var/www/osm2postgis"

# Command to be run when container starts.
CMD [ "/bin/bash" ]


# CMD osm2pgsql -d postgres --port 5433 -H postgis -U postgres -W -c --prefix=schwaben -k -S "/usr/share/osm2pgsql/default.style" osmdata.osm.pbf
