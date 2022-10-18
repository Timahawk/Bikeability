# A Bikeabiltiy framework

## Abstract 
Over the last 25 years, the number of cyclists in Germany has increased by over 40% (Hudde, 2022). Yet, the tools to assess the quality of cycling infrastructure on a broad scale are lacking. Currently, no unified evaluation technique exists that can be used to compare complete cities regarding their cycling infrastructure. The following thesis develops a framework to address this issue. The proposed framework uses open source and open data to conform with the ideas of open science. Furthermore, it aims to be easy to configure and simple to use, while still allowing for the technical complexity to run fast and efficient. To achieve this, the model uses microservice software architecture style and containerization. To be able to assess the bikeability citywide as well as on an individual street level, the framework employs a semi-random algorithm to model the relevancy of individual roads. The generated origin-destination pairs are connected by routes produced with the cycling-specific routing engine, Brouter. Lastly, the framework comes preconfigured with a proof-of-concept model, based on existing bikeability research. By comparing the citywide results with other indices, as well as comparing the score of individual roads with local experts, the underlying idea of the framework could be validated.

Read the complete [master thesis](/Thesis/Wendel_Tim_Developing_Bikeabilty_framework.pdf).

## Proposed Goals
-	The framework should enable researchers to generate a single citywide bikeability score.
-	The index should be comparable between cities.
-	The framework should generate a per road bikeability score.
-	The road bikeability score should reflect the importance of this segment.
-	Aligning with the ideas of open science, it should be reproducible.
-	The underlying model should be highly configurable.
-	The score should be calculated without major intervention.
-	The framework offers a good overall performance.

## Data Flow
![Data flow](/Thesis/FlowDiagram.png)

## Framework architecture

![Architecture](/Thesis/architecture.png)

# Using the model

## How to generate a Bikeabilty score for a single city:

### Get the required segments (data) files for Brouter:

Routing data files are organised as 5*5 degree files,
with the filename containing the south-west corner
of the square, which means:

- You want to route near East7/North47 -> you need `E5_N45.rd5`
- You want to route near East11/North51 -> you need `E10_N50.rd5`

These data files, called "segments" across BRouter, are generated from
[OpenStreetMap](https://www.openstreetmap.org/) data and stored in a custom
binary format (rd5) for improved efficiency of BRouter routing.

Segments files from the whole planet are generated weekly at
[https://brouter.de/brouter/segments4/](http://brouter.de/brouter/segments4/).

You must download one or more segments files, covering the area of the planet
you want to route, and copy them in the folder `./brouter/segments4`

### Get the required OSM data:

Checkout the [list of cities](/stadtliste.csv) to get a hint for the possible areas.\
Download the files from [Geofabrik](https://download.geofabrik.de/europe/germany.html)\
Safe the files in the [Data Folder](/data).

### Configure the framework to your needs:

Check out the [Config Files](/config.env) and [Score File](/sql_files/scoreViews.sql) to configure the framework.

### Change Batchscript

Change *schemaname*, *cityname* and *file* in the [Batch File](/batchscript.bat) to run the model.\

*schemaname* must be a single world all lower case representing the city.\
*cityname* must be the exact name of the city district within OpenStreetMap. **Caps Sensitve**\
*file* must be the path to your downloaded osm data file.

### Execute the Batchscript.

Execute the [Batch File](/batchscript.bat).\
City wide results will appear in the [Go_results](/go_result/) Folder.
Individual segments results can be seen in the postgres database.\
Data is accessable via `postgresql://postgres:postgres@localhost:5433/postgres`


## How to generate a Bikeabilty for all cities in [list of cities](/stadtliste.csv):

### Downloads

Download the four Brouter segments:
- E5_N45.rd5
- E5_N50.rd5
- E10_N50.rd5
- E10_N45.rd5

Download the data files:
- sachsen-latest.osm.pbf
- schleswig-holstein-latest.osm.pbf
- schwaben-latest.osm.pbf
- thueringen-latest.osm.pbf
- andorra-latest.osm.pbf
- arnsberg-regbez-latest.osm.pbf
- bremen-latest.osm.pbf
- detmold-regbez-latest.osm.pbf
- duesseldorf-regbez-latest.osm.pbf
- freiburg-regbez-latest.osm.pbf
- hessen-latest.osm.pbf
- karlsruhe-regbez-latest.osm.pbf
- koeln-regbez-latest.osm.pbf
- mecklenburg-vorpommern-latest.osm.pbf
- mittelfranken-latest.osm.pbf
- muenster-regbez-latest.osm.pbf
- niedersachsen-latest.osm.pbf
- rheinland-pfalz-latest.osm.pbf
- sachsen-anhalt-latest.osm.pbf

### Change Batchscript

Comment out the set commands for *schemaname*, *cityname* and *file* in the [Batch File](/batchscript.bat)\
Execute the provided python3 [script](score_all.py)