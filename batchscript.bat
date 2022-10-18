
chcp 65001 
@echo off

set schemaname=augsburg
set cityname=Augsburg
set file=./data/schwaben-latest.osm.pbf

echo Currently working on %cityname% based on %file%

docker compose up --detach postgis

timeout /t 10

docker compose exec postgis psql -c "CREATE EXTENSION IF NOT EXISTS hstore;" -Atx "postgresql://postgres:postgres@postgis:5432/postgres"

docker compose exec postgis psql -c "DROP SCHEMA  IF EXISTS %schemaname% CASCADE; " -Atx "postgresql://postgres:postgres@postgis:5432/postgres"
docker compose exec postgis psql -c "CREATE SCHEMA %schemaname%;" -Atx "postgresql://postgres:postgres@postgis:5432/postgres"

REM it is not good how that the pbf files are to be downloaded before but.. could not make it work otherwise.
docker compose run --rm osm2pg osm2pgsql -d "postgresql://postgres:postgres@postgis:5432/postgres" -c --middle-schema=%schemaname%  --output-pgsql-schema=%schemaname% --prefix=world -k -S "/usr/share/osm2pgsql/default.style" %file%

@REM pause

docker compose exec postgis psql -v v1=%schemaname% -v v2="%cityname%" -f /home/sqlfiles/setupTables.sql -Atx "postgresql://postgres:postgres@postgis:5432/postgres"
docker compose exec postgis psql -v v1=%schemaname% -v v2="%cityname%" -f /home/sqlfiles/location_views.sql -Atx "postgresql://postgres:postgres@postgis:5432/postgres"
docker compose exec postgis psql -v v1=%schemaname% -v v2="%cityname%" -f /home/sqlfiles/generateTables.sql -Atx "postgresql://postgres:postgres@postgis:5432/postgres"
docker compose exec postgis psql -v v1=%schemaname% -v v2="%cityname%" -f /home/sqlfiles/scoreViews.sql -Atx "postgresql://postgres:postgres@postgis:5432/postgres"

docker compose run --rm go_generate_routes go run . %schemaname%
docker compose run --rm go_result go run . %schemaname%

docker compose stop brouter
docker compose stop traefik
@REM docker compose rm -f
