----------- Interkommunal -------------------------------------------------------------------schwaben
DROP VIEW IF EXISTS :v1.Grenzen_Interkommunal;
CREATE VIEW :v1.Grenzen_Interkommunal AS 
	SELECT 
    :v1.world_polygon.poly_id,
    :v1.world_polygon.osm_id,
		:v1.world_polygon.admin_level,
		:v1.world_polygon.boundary,
		:v1.world_polygon.name,
		:v1.world_polygon.place,
		:v1.world_polygon.z_order,
		:v1.world_polygon.tags,
		:v1.world_polygon.way_area,
		:v1.world_polygon.way
		FROM :v1.world_polygon
	WHERE :v1.world_polygon.boundary IS NOT NULL AND :v1.world_polygon.admin_level::integer >= 9;


----------- Gemeinde ---------------------------------------------------------------------
DROP VIEW IF EXISTS :v1.Grenzen_Gemeinde;
CREATE VIEW :v1.Grenzen_Gemeinde AS
		SELECT 
    :v1.world_polygon.poly_id,
    :v1.world_polygon.osm_id,
		:v1.world_polygon.admin_level,
		:v1.world_polygon.boundary,
		:v1.world_polygon.name,
		:v1.world_polygon.place,
		:v1.world_polygon.z_order,
		:v1.world_polygon.tags,
		:v1.world_polygon.way_area,
		:v1.world_polygon.way
		FROM :v1.world_polygon
	WHERE :v1.world_polygon.boundary IS NOT NULL AND :v1.world_polygon.admin_level::integer = 7 OR :v1.world_polygon.admin_level::integer = 8;


----------- Landkreise -------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS :v1.Grenzen_Landkreis CASCADE;
CREATE MATERIALIZED VIEW :v1.Grenzen_Landkreis AS 
	SELECT 
    :v1.world_polygon.poly_id,
    :v1.world_polygon.osm_id,
		:v1.world_polygon.admin_level,
		:v1.world_polygon.boundary,
		:v1.world_polygon.name,
		:v1.world_polygon.place,
		:v1.world_polygon.z_order,
		:v1.world_polygon.tags,
		:v1.world_polygon.way_area,
		:v1.world_polygon.way
		FROM :v1.world_polygon
	WHERE :v1.world_polygon.boundary IS NOT NULL AND :v1.world_polygon.admin_level::integer = 6;

CREATE INDEX IF NOT EXISTS landkreis_geom_idx
    ON :v1.grenzen_landkreis USING gist
    (way)
    TABLESPACE pg_default;



-------- Local Line -------------------------------------------------------------------------
DROP VIEW IF EXISTS :v1.lines;
CREATE VIEW :v1.lines AS 
	SELECT
		*
	FROM :v1.world_line 
	WHERE ST_INTERSECTS(way, (SELECT way FROM :v1.Grenzen_Landkreis WHERE Name = :'v2' ORDER BY way_area DESC LIMIT 1));

-- CREATE INDEX lines_geom_idx
--     ON lines USING gist
--     (way);

-------- Local Polygon -------------------------------------------------------------------------
DROP  VIEW IF EXISTS :v1.polygons;
CREATE  VIEW :v1.polygons AS 
	SELECT
		*
	FROM :v1.world_polygon
	WHERE ST_INTERSECTS(way, (SELECT way FROM :v1.Grenzen_Landkreis WHERE Name = :'v2' ORDER BY way_area DESC LIMIT 1));

-- CREATE INDEX polygons_geom_idx
--     ON polygons USING gist
--     (way);

-- CREATE INDEX polygons_buildings_idx
--     ON polygons USING btree
--     (building);


-------- Local Points -------------------------------------------------------------------------
DROP  VIEW IF EXISTS :v1.points;
CREATE VIEW :v1.points AS 
	SELECT
		*
	FROM :v1.world_point
	WHERE ST_INTERSECTS(way, (SELECT way FROM :v1.Grenzen_Landkreis WHERE Name = :'v2' ORDER BY way_area DESC LIMIT 1));

-- CREATE INDEX points_geom_idx
--     ON points USING gist
--     (way);

----------- Buildings --------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS :v1.buildings;
CREATE MATERIALIZED VIEW :v1.buildings AS
    SELECT 
      poly_id,
      row_number() OVER () AS building_id, 
      osm_id, 
      building, 
      "addr:housenumber", 
      name,
      shop,  
      layer, 
      z_order, 
      way_area, 
      way, 
      tags 
      FROM :v1.world_polygon
	    WHERE ST_WITHIN(way, (SELECT way FROM :v1.Grenzen_Landkreis WHERE Name = :'v2' ORDER BY way_area DESC LIMIT 1))
		AND building IS NOT NULL;



----- Cyclosm amenities point ------------------------------------
DROP VIEW IF EXISTS :v1.cyclosm_amenities_point;
CREATE VIEW :v1.cyclosm_amenities_point AS
    SELECT
          point_id,
          access,
          bicycle,
          tags->'mtb' AS mtb,
          covered,
          tags->'shelter' AS shelter,
          way,
          name,
          COALESCE( -- order is important here
            'aeroway_' || CASE WHEN aeroway IN ('helipad', 'aerodrome') THEN aeroway ELSE NULL END,
            'tourism_' || CASE WHEN tourism IN ('artwork', 'alpine_hut', 'camp_site', 'caravan_site', 'chalet', 'wilderness_hut', 'guest_house', 'apartment', 'hostel', 'hotel', 'motel', 'information', 'museum', 'viewpoint', 'picnic_site', 'gallery') THEN tourism ELSE NULL END,
            'shop_' ||  CASE WHEN shop IN ('bicycle', 'bakery', 'beverage', 'convenience', 'convenience;gas', 'doityourself', 'gas', 'greengrocer', 'supermarket', 'pastry', 'sports') THEN shop ELSE NULL END,
            'amenity_' || CASE WHEN amenity IN ('atm', 'bank', 'bar', 'bench', 'bicycle_rental', 'bicycle_parking', 'bicycle_repair_station', 'biergarten', 'cafe', 'car_wash', 'compressed_air', 'community_centre', 'clinic', 'doctors', 'drinking_water', 'fast_food', 'ferry_terminal', 'food_court', 'fountain', 'fuel', 'hospital', 'ice_cream', 'internet_cafe', 'parking', 'pharmacy', 'place_of_worship', 'police', 'post_office', 'post_box', 'pub', 'public_bath', 'restaurant', 'shelter', 'shower', 'toilets', 'water_point', 'cinema', 'theatre', 'bureau_de_change', 'casino', 'library', 'motorcycle_parking', 'charging_station', 'vending_machine') THEN amenity ELSE NULL END,
            'shop_' || CASE WHEN tags->'service:bicycle:retail'='yes' OR tags->'service:bicycle:repair'='yes' OR tags->'service:bicycle:rental'='yes' THEN 'bicycle' ELSE NULL END,
            'emergency_' || CASE WHEN tags->'emergency' IS NOT NULL THEN tags->'emergency' ELSE NULL END,
            'healthcare_' || CASE WHEN tags->'healthcare' IN ('clinic', 'hospital') THEN tags->'healthcare' ELSE NULL END,
            'leisure_' || CASE WHEN leisure IN ('picnic_table', 'sports_centre') THEN leisure ELSE NULL END,
            'man_made_' || CASE WHEN man_made IN ('mast', 'tower', 'water_tower', 'lighthouse', 'windmill', 'cross', 'obelisk', 'communications_tower', 'telescope', 'chimney', 'crane', 'storage_tank', 'silo', 'water_tap', 'monitoring_station') THEN man_made ELSE NULL END,
            CASE WHEN tags->'mountain_pass' = 'yes' THEN 'mountain_pass' ELSE NULL END,
            'natural_' || CASE WHEN "natural" IN ('peak', 'volcano', 'saddle', 'spring', 'cave_entrance') THEN "natural" ELSE NULL END,
            'place_' || CASE WHEN place IN ('island', 'islet') THEN place END,
            'waterway_' || CASE WHEN waterway IN ('waterfall') THEN waterway ELSE NULL END,
            'historic_' || CASE WHEN historic IN ('memorial', 'monument', 'archaeological_site', 'wayside_cross', 'fort', 'wayside_shrine', 'castle', 'manor', 'city_gate') THEN historic ELSE NULL END,
            'military_'|| CASE WHEN military IN ('bunker') THEN military ELSE NULL END,
            'highway_'|| CASE WHEN highway IN ('bus_stop', 'elevator', 'traffic_signals') THEN highway ELSE NULL END,
            'highway_' || CASE WHEN tags @> 'ford=>yes' OR tags @> 'ford=>stepping_stones' THEN 'ford' END,
            'power_' || power,
            'xmas_' || CASE WHEN tags->'xmas:feature' IN ('tree', 'market') AND (EXTRACT(MONTH FROM CURRENT_DATE) = '12') AND (EXTRACT(DAY FROM CURRENT_DATE) >= '1') THEN tags->'xmas:feature' ELSE NULL END
          ) AS feature,
          CASE
            WHEN tags->'capacity'~E'^\\d+$' THEN (tags->'capacity')::integer
            ELSE NULL
          END AS capacity,
          religion,
          tags->'denomination' AS denomination,
          tags->'compressed_air' AS compressed_air,
          tags->'service:bicycle:pump' AS service_bicycle_pump,
          tags->'service:bicycle:diy' AS service_bicycle_diy,
          CASE
            WHEN tags->'service:bicycle:retail'='yes' OR tags->'service:bicycle:repair'='yes' OR tags->'service:bicycle:rental'='yes' THEN 'yes' ELSE NULL
          END AS service_bicycle_retail_repair_rental,
          tags->'car_wash' as car_wash,
          tags->'drinking_water' AS drinking_water,
          tags->'location' AS location,
          tags->'memorial' AS memorial,
          tags->'castle_type' AS castle_type,
          tags->'information' AS information,
          tags->'artwork_type' as artwork_type,
          tags->'icao' as icao,
          tags->'iata' as iata,
          "generator:source",
          tags->'supervised' as supervised,
          tags->'bicycle_parking' as bicycle_parking,
          tags->'vending' as vending,
          tags->'automated' as automated,
          CASE
            WHEN "natural" IN ('peak', 'volcano', 'saddle')
              OR tags->'mountain_pass' = 'yes' THEN
              CASE
                WHEN ele ~ '^-?\d{1,4}(\.\d+)?$' THEN ele::NUMERIC
                ELSE NULL
              END
            WHEN "waterway" IN ('waterfall') THEN
              CASE
                WHEN tags->'height' ~ '^\d{1,3}(\.\d+)?( m)?$' THEN (SUBSTRING(tags->'height', '^(\d{1,3}(\.\d+)?)( m)?$'))::NUMERIC
              ELSE NULL
              END
            WHEN tags->'capacity'~E'^\\d+$' THEN (tags->'capacity')::integer
            ELSE NULL
          END AS score,
          CASE
            WHEN "natural" IN ('peak', 'volcano', 'saddle')
              OR tourism = 'alpine_hut' OR (tourism = 'information' AND tags->'information' = 'guidepost')
              OR amenity = 'shelter'
              OR tags->'mountain_pass' = 'yes'
              THEN
              CASE
                WHEN ele ~ '^-?\d{1,4}(\.\d+)?$' THEN ele::NUMERIC
                ELSE NULL
              END
            ELSE NULL
          END AS elevation,
          CASE
            WHEN (man_made IN ('mast', 'tower', 'chimney', 'crane') AND (tags->'location' NOT IN ('roof', 'rooftop') OR (tags->'location') IS NULL)) OR waterway IN ('waterfall') THEN
              CASE
                WHEN tags->'height' ~ '^\d{1,3}(\.\d+)?( m)?$' THEN (SUBSTRING(tags->'height', '^(\d{1,3}(\.\d+)?)( m)?$'))::NUMERIC
              ELSE NULL
            END
            ELSE NULL
          END AS height
        FROM :v1.world_point
        WHERE (aeroway IN ('helipad', 'aerodrome')
          OR tourism IN ('artwork', 'alpine_hut', 'camp_site', 'caravan_site', 'chalet', 'wilderness_hut', 'guest_house', 'apartment', 'hostel',
              'hotel', 'motel', 'information', 'museum', 'viewpoint', 'picnic_site', 'gallery')
          OR amenity IN ('atm', 'bank', 'bar', 'bench', 'bicycle_rental', 'bicycle_parking', 'bicycle_repair_station',
                         'biergarten', 'cafe', 'car_wash', 'compressed_air', 'community_centre', 'clinic', 'doctors', 'drinking_water', 'fast_food',
                         'ferry_terminal', 'food_court', 'fountain', 'fuel', 'hospital', 'ice_cream', 'internet_cafe',
                         'parking', 'pharmacy', 'place_of_worship', 'police', 'post_office', 'post_box', 'pub', 'public_bath',
                         'restaurant', 'shelter', 'shower', 'toilets', 'water_point', 'cinema', 'theatre',
                         'bureau_de_change', 'casino', 'library')
          OR tags->'car_wash'='yes'
          OR (amenity='motorcycle_parking' AND (bicycle='yes' OR bicycle='designated'))
          OR (amenity='charging_station' AND (bicycle='yes' OR bicycle='designated'))
          OR (amenity='vending_machine' AND tags->'vending'='bicycle_tube')
          OR shop IN ('bicycle', 'bakery', 'beverage', 'convenience', 'convenience;gas', 'doityourself', 'gas', 'greengrocer', 'supermarket', 'pastry', 'sports')
          OR tags->'healthcare' IN ('clinic', 'hospital')
          OR leisure='picnic_table'
          OR (leisure='sports_centre' AND sport='swimming')
          OR (
            man_made IN ('mast', 'tower', 'water_tower', 'lighthouse', 'windmill', 'cross', 'obelisk', 'communications_tower', 'telescope', 'chimney', 'crane', 'storage_tank', 'silo')
            AND (tags->'location' NOT IN ('roof', 'rooftop') OR (tags->'location') IS NULL)
          )
          OR man_made IN ('water_tap')
          OR man_made IN ('monitoring_station') AND tags->'monitoring:bicycle'='yes'
          OR "natural" IN ('peak', 'volcano', 'saddle', 'spring', 'cave_entrance')
          OR place IN ('island', 'islet')
          OR tags->'mountain_pass' = 'yes'
          OR waterway IN ('waterfall')
          OR historic IN ('memorial', 'monument', 'archaeological_site', 'wayside_cross', 'fort', 'wayside_shrine', 'castle', 'manor', 'city_gate')
          OR military IN ('bunker')
          OR tags->'emergency' IN ('defibrillator', 'phone')
          OR highway IN ('elevator', 'traffic_signals')
          OR ((highway='bus_stop' OR public_transport='platform') AND (tags->'shelter'='yes' OR covered='yes'))
          OR (power = 'generator' AND "generator:source"='wind')
          OR tags->'ford' IS NOT NULL
          OR tags->'xmas:feature' IN ('tree', 'market')
          OR tags->'service:bicycle:retail'='yes' OR tags->'service:bicycle:repair'='yes' OR tags->'service:bicycle:rental'='yes')
		AND 
		  ST_WITHIN(way, (SELECT way FROM :v1.Grenzen_Landkreis WHERE Name = :'v2' ORDER BY way_area DESC LIMIT 1))
        ORDER BY
            CASE
                -- Bike amenities
                WHEN shop IN ('bicycle', 'sports') THEN 0
                WHEN amenity IN ('bicycle_rental') Then 10
                -- Emergency
                WHEN tags->'healthcare' IS NOT NULL OR tags->'emergency' IN ('defibrillator', 'phone') OR amenity IN ('hospital', 'clinic', 'doctors', 'pharmacy') THEN 20
                -- Other emergency-related amenities
                WHEN amenity IN ('bicycle_repair_station', 'compressed_air', 'drinking_water', 'police', 'toilets',
                  'water_point', 'charging_station') THEN 21
                WHEN tags->'compressed_air'='yes' THEN 22
                --- Parkings
                WHEN amenity IN ('bicycle_parking', 'motorcycle_parking') THEN 32
                -- Supermarkets
                WHEN shop='supermarket' THEN 40
                -- Convenience
                WHEN shop='convenience' OR shop='convenience;gas' THEN 50
                -- Food
                WHEN shop IS NOT NULL OR amenity IN ('bar', 'biergarten', 'cafe', 'fast_food', 'food_court', 'pub', 'restaurant') THEN 60
                -- Everything else
                ELSE NULL
            END ASC NULLS LAST,
            feature,
            score DESC NULLS LAST;


----- Cyclosm amenities polygon ----------------------------------
DROP VIEW IF EXISTS :v1.cyclosm_amenities_poly;
CREATE VIEW :v1.cyclosm_amenities_poly AS
    SELECT
          poly_id,
          access,
          bicycle,
          tags->'mtb' AS mtb,
          covered,
          tags->'shelter' AS shelter,
          way,
          way_area AS area,
          name,
          COALESCE( -- order is important here
            'aeroway_' || CASE WHEN aeroway IN ('helipad', 'aerodrome') THEN aeroway ELSE NULL END,
            'tourism_' || CASE WHEN tourism IN ('artwork', 'alpine_hut', 'camp_site', 'caravan_site', 'chalet', 'wilderness_hut', 'guest_house', 'apartment', 'hostel', 'hotel', 'motel', 'information', 'museum', 'viewpoint', 'picnic_site', 'gallery') THEN tourism ELSE NULL END,
            'shop_' ||  CASE WHEN shop IN ('bicycle', 'bakery', 'beverage', 'convenience', 'convenience;gas', 'doityourself', 'gas', 'greengrocer', 'supermarket', 'pastry', 'sports') THEN shop ELSE NULL END,
            'amenity_' || CASE WHEN amenity IN ('atm', 'bank', 'bar', 'bench', 'bicycle_rental', 'bicycle_parking', 'bicycle_repair_station', 'biergarten', 'cafe', 'car_wash', 'compressed_air', 'community_centre', 'clinic', 'doctors', 'drinking_water', 'fast_food', 'ferry_terminal', 'food_court', 'fountain', 'fuel', 'hospital', 'ice_cream', 'internet_cafe', 'parking', 'pharmacy', 'place_of_worship', 'police', 'post_office', 'post_box', 'pub', 'public_bath', 'restaurant', 'shelter', 'shower', 'toilets', 'water_point', 'cinema', 'theatre', 'bureau_de_change', 'casino', 'library', 'motorcycle_parking', 'charging_station', 'vending_machine') THEN amenity ELSE NULL END,
            'shop_' || CASE WHEN tags->'service:bicycle:retail'='yes' OR tags->'service:bicycle:repair'='yes' OR tags->'service:bicycle:rental'='yes' THEN 'bicycle' ELSE NULL END,
            'emergency_' || CASE WHEN tags->'emergency' IS NOT NULL THEN tags->'emergency' ELSE NULL END,
            'healthcare_' || CASE WHEN tags->'healthcare' IN ('clinic', 'hospital') THEN tags->'healthcare' ELSE NULL END,
            'leisure_' || CASE WHEN leisure IN ('picnic_table', 'sports_centre') THEN leisure ELSE NULL END,
            'man_made_' || CASE WHEN man_made IN ('mast', 'tower', 'water_tower', 'lighthouse', 'windmill', 'cross', 'obelisk', 'communications_tower', 'telescope', 'chimney', 'crane', 'storage_tank', 'silo', 'water_tap', 'monitoring_station') THEN man_made ELSE NULL END,
            CASE WHEN tags->'mountain_pass' = 'yes' THEN 'mountain_pass' ELSE NULL END,
            'natural_' || CASE WHEN "natural" IN ('peak', 'volcano', 'saddle', 'spring', 'cave_entrance') THEN "natural" ELSE NULL END,
            'place_' || CASE WHEN place IN ('island', 'islet') THEN place END,
            'waterway_' || CASE WHEN waterway IN ('waterfall') THEN waterway ELSE NULL END,
            'historic_' || CASE WHEN historic IN ('memorial', 'monument', 'archaeological_site', 'wayside_cross', 'fort', 'wayside_shrine', 'castle', 'manor', 'city_gate') THEN historic ELSE NULL END,
            'military_'|| CASE WHEN military IN ('bunker') THEN military ELSE NULL END,
            'highway_'|| CASE WHEN highway IN ('bus_stop', 'elevator', 'traffic_signals') THEN highway ELSE NULL END,
            'power_' || power,
            'xmas_' || CASE WHEN tags->'xmas:feature' IN ('tree', 'market') AND (EXTRACT(MONTH FROM CURRENT_DATE) = '12') AND (EXTRACT(DAY FROM CURRENT_DATE) >= '1') THEN tags->'xmas:feature' ELSE NULL END
          ) AS feature,
          CASE
            WHEN tags->'capacity'~E'^\\d+$' THEN (tags->'capacity')::integer
            ELSE NULL
          END AS capacity,
          religion,
          tags->'denomination' AS denomination,
          tags->'compressed_air' AS compressed_air,
          tags->'service:bicycle:pump' AS service_bicycle_pump,
          tags->'service:bicycle:diy' AS service_bicycle_diy,
          CASE
            WHEN tags->'service:bicycle:retail'='yes' OR tags->'service:bicycle:repair'='yes' OR tags->'service:bicycle:rental'='yes' THEN 'yes' ELSE NULL
          END AS service_bicycle_retail_repair_rental,
          tags->'car_wash' as car_wash,
          tags->'drinking_water' AS drinking_water,
          tags->'location' AS location,
          tags->'memorial' AS memorial,
          tags->'castle_type' AS castle_type,
          tags->'information' AS information,
          tags->'artwork_type' as artwork_type,
          tags->'icao' as icao,
          tags->'iata' as iata,
          "generator:source",
          tags->'supervised' as supervised,
          tags->'bicycle_parking' as bicycle_parking,
          tags->'vending' as vending,
          tags->'automated' as automated,
          CASE
            WHEN "natural" IN ('peak', 'volcano', 'saddle') THEN NULL
            WHEN "waterway" IN ('waterfall') THEN
              CASE
                WHEN tags->'height' ~ '^\d{1,3}(\.\d+)?( m)?$' THEN (SUBSTRING(tags->'height', '^(\d{1,3}(\.\d+)?)( m)?$'))::NUMERIC
              ELSE NULL
              END
            WHEN tags->'capacity'~E'^\\d+$' THEN (tags->'capacity')::integer
            ELSE NULL
          END AS score,
          CASE
            WHEN (man_made IN ('mast', 'tower', 'chimney', 'crane') AND (tags->'location' NOT IN ('roof', 'rooftop') OR (tags->'location') IS NULL)) OR waterway IN ('waterfall') THEN
              CASE
                WHEN tags->'height' ~ '^\d{1,3}(\.\d+)?( m)?$' THEN (SUBSTRING(tags->'height', '^(\d{1,3}(\.\d+)?)( m)?$'))::NUMERIC
              ELSE NULL
            END
            ELSE NULL
          END AS height,
          way_area
        FROM :v1.world_polygon
        WHERE (aeroway IN ('helipad', 'aerodrome')
          OR tourism IN ('artwork', 'alpine_hut', 'camp_site', 'caravan_site', 'chalet', 'wilderness_hut', 'guest_house', 'apartment', 'hostel',
              'hotel', 'motel', 'information', 'museum', 'viewpoint', 'picnic_site', 'gallery')
          OR amenity IN ('atm', 'bank', 'bar', 'bench', 'bicycle_rental', 'bicycle_parking', 'bicycle_repair_station',
                         'biergarten', 'cafe', 'car_wash', 'compressed_air', 'community_centre', 'clinic', 'doctors', 'drinking_water', 'fast_food',
                         'ferry_terminal', 'food_court', 'fountain', 'fuel', 'hospital', 'ice_cream', 'internet_cafe',
                         'parking', 'pharmacy', 'place_of_worship', 'police', 'post_office', 'post_box', 'pub', 'public_bath',
                         'restaurant', 'shelter', 'shower', 'toilets', 'water_point', 'cinema', 'theatre',
                         'bureau_de_change', 'casino', 'library')
          OR tags->'car_wash'='yes'
          OR (amenity='motorcycle_parking' AND (bicycle='yes' OR bicycle='designated'))
          OR (amenity='charging_station' AND (bicycle='yes' OR bicycle='designated'))
          OR (amenity='vending_machine' AND tags->'vending'='bicycle_tube')
          OR shop IN ('bicycle', 'bakery', 'beverage', 'convenience', 'convenience;gas', 'doityourself', 'gas', 'greengrocer', 'supermarket', 'pastry', 'sports')
          OR tags->'healthcare' IN ('clinic', 'hospital')
          OR leisure='picnic_table'
          OR (leisure='sports_centre' AND sport='swimming')
          OR (
            man_made IN ('mast', 'tower', 'water_tower', 'lighthouse', 'windmill', 'cross', 'obelisk', 'communications_tower', 'telescope', 'chimney', 'crane', 'storage_tank', 'silo')
            AND (tags->'location' NOT IN ('roof', 'rooftop') OR (tags->'location') IS NULL)
          )
          OR man_made IN ('water_tap')
          OR man_made IN ('monitoring_station') AND tags->'monitoring:bicycle'='yes'
          OR "natural" IN ('peak', 'volcano', 'saddle', 'spring', 'cave_entrance')
		  OR place IN ('island', 'islet')
          OR tags->'mountain_pass' = 'yes'
          OR waterway IN ('waterfall')
          OR historic IN ('memorial', 'monument', 'archaeological_site', 'wayside_cross', 'fort', 'wayside_shrine', 'castle', 'manor', 'city_gate')
          OR military IN ('bunker')
          OR tags->'emergency' IN ('defibrillator', 'phone')
          OR highway IN ('elevator', 'traffic_signals')
          OR ((highway='bus_stop' OR public_transport='platform') AND (tags->'shelter'='yes' OR covered='yes'))
          OR (power = 'generator' AND "generator:source"='wind')
          OR tags->'xmas:feature' IN ('tree', 'market')
          OR tags->'service:bicycle:retail'='yes' OR tags->'service:bicycle:repair'='yes' OR tags->'service:bicycle:rental'='yes')
		AND
			ST_WITHIN(way, (SELECT way FROM :v1.Grenzen_Landkreis WHERE Name = :'v2' ORDER BY way_area DESC LIMIT 1))
        ORDER BY
            CASE
                -- Bike amenities
                WHEN shop IN ('bicycle', 'sports') THEN 0
                WHEN amenity IN ('bicycle_rental') Then 10
                -- Emergency
                WHEN tags->'healthcare' IS NOT NULL OR tags->'emergency'IN ('defibrillator', 'phone') OR amenity IN ('hospital', 'clinic', 'doctors', 'pharmacy') THEN 20
                -- Other emergency-related amenities
                WHEN amenity IN ('bicycle_repair_station', 'compressed_air', 'drinking_water', 'police', 'toilets',
                  'water_point', 'charging_station') THEN 21
                WHEN tags->'compressed_air'='yes' THEN 22
                --- Parkings
                WHEN amenity IN ('bicycle_parking', 'motorcycle_parking') THEN 32
                -- Supermarkets
                WHEN shop='supermarket' THEN 40
                -- Convenience
                WHEN shop='convenience' OR shop='convenience;gas' THEN 50
                -- Food
                WHEN shop IS NOT NULL OR amenity IN ('bar', 'biergarten', 'cafe', 'fast_food', 'food_court', 'pub', 'restaurant') THEN 60
                -- Everything else
                ELSE NULL
            END ASC NULLS LAST,
            feature,
            score DESC NULLS LAST;


---------- TRAFFIC LIGHTS VIEW -----------------------------------
DROP VIEW IF EXISTS :v1.traffic_lights;
CREATE VIEW :v1.traffic_lights AS
SELECT * 
FROM 
	:v1.world_point 
WHERE 
	ST_WITHIN(way, (SELECT way FROM :v1.Grenzen_Landkreis WHERE Name = :'v2' ORDER BY way_area DESC LIMIT 1))
AND highway = 'traffic_signals';
	
	
---------- ZEBRA STREIFEN VIEW -----------------------------------
DROP VIEW IF EXISTS :v1.crossings;
CREATE VIEW :v1.crossings AS
SELECT *
FROM 
	:v1.world_point 
WHERE 
	ST_WITHIN(way, (SELECT way FROM :v1.Grenzen_Landkreis WHERE Name = :'v2' ORDER BY way_area DESC LIMIT 1))
AND highway = 'crossing';


-------- Railway VIEW --------------------
DROP VIEW IF EXISTS :v1.railway;
CREATE VIEW :v1.railway AS	
SELECT row_number() over() as rail_id, * FROM :v1.world_line 
WHERE 
	ST_INTERSECTS(way, (SELECT way FROM :v1.Grenzen_Landkreis WHERE Name = :'v2' ORDER BY way_area DESC LIMIT 1))
AND
	railway IS NOT NULL;


-------- Railway Crossings --------------------
DROP VIEW IF EXISTS :v1.railway_crossings;
CREATE VIEW :v1.railway_crossings AS	
SELECT osm_id, railway, bicycle, tags, way FROM :v1.world_point
WHERE 
	ST_WITHIN(way, (SELECT way FROM :v1.Grenzen_Landkreis WHERE Name = :'v2' ORDER BY way_area DESC LIMIT 1))
AND
	railway IS NOT NULL;



-- View showing possible destinations -----------------------------------------------------
-------------------------------------------------------------------------------------------

DROP VIEW IF EXISTS :v1.points_to_go; 
CREATE  VIEW :v1.points_to_go AS (
SELECT 
  point_id,
  access,amenity, tourism, shop, leisure, historic, office, brand,name, operator, sport, tags, way  
FROM :v1.world_point
	WHERE
    ST_WITHIN(way, (SELECT way FROM :v1.Grenzen_Landkreis WHERE Name = :'v2' ORDER BY way_area DESC LIMIT 1))
  AND (
    amenity IN ('bank', 'bar', 'bicycle_rental', 'bicycle_repair_station',
          'biergarten', 'cafe', 'community_centre', 'clinic', 'doctors', 'fast_food',
          'ferry_terminal', 'food_court', 'hospital', 'ice_cream', 'internet_cafe',
          'pharmacy', 'place_of_worship', 'police', 'post_office', 'pub', 'public_bath',
          'restaurant',  'cinema', 'theatre', 'bureau_de_change', 'casino', 'library')
    OR
    tourism IN ('artwork', 'alpine_hut', 'camp_site', 'caravan_site', 'chalet', 'wilderness_hut', 'guest_house', 'apartment', 'hostel',
                'hotel', 'motel', 'museum', 'viewpoint', 'picnic_site', 'gallery')
    OR 
    shop IS NOT NULL
    OR
    sport IS NOT NULL
    OR
    historic IN ('memorial', 'technical_monument')
    OR
    office IS NOT NULL
    OR
    leisure IN ('stadium', 'playground', 'dog_park', 'park', 'fitness_station')
  )
);

-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS :v1.destinations;
CREATE MATERIALIZED VIEW :v1.destinations AS (
	SELECT 
		row_number() over() as dest_id,
		*
	FROM (
		SELECT point_id, 0 as poly_id, way FROM :v1.points_to_go
		UNION
		SELECT 0 as point_id, poly_id, ST_Centroid(way) FROM :v1.buildings WHERE way_area > 100
	) X
	ORDER BY poly_id
);

CREATE INDEX destinations_dest_id_idx
    ON :v1.destinations USING btree
    (dest_id);

CREATE INDEX destinations_point_id_idx
    ON :v1.destinations USING btree
    (point_id);

CREATE INDEX destinations_poly_id_idx
    ON :v1.destinations USING btree
    (poly_id);


-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------

CREATE OR REPLACE VIEW :v1.bicycle_parking AS 
SELECT 
	point_id, amenity, covered, tags, surface, way
	FROM :v1.world_point 
	WHERE ST_WITHIN(way, (SELECT way FROM :v1.Grenzen_Landkreis WHERE Name = :'v2' ORDER BY way_area DESC LIMIT 1))
	AND amenity ='bicycle_parking';

-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------

CREATE OR REPLACE VIEW :v1.bicycle_shops AS
SELECT 
	point_id, name, shop, tags,way
	FROM :v1.world_point 
	WHERE ST_WITHIN(way, (SELECT way FROM :v1.Grenzen_Landkreis WHERE Name = :'v2' ORDER BY way_area DESC LIMIT 1))
	AND shop ='bicycle';

-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------

	
CREATE OR REPLACE VIEW :v1.bicycle_rental AS 
SELECT 
	point_id, amenity, brand,operator, tags, surface, way
	FROM :v1.world_point 
	WHERE ST_WITHIN(way, (SELECT way FROM :v1.Grenzen_Landkreis WHERE Name = :'v2' ORDER BY way_area DESC LIMIT 1))
	AND amenity ='bicycle_rental';

-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------

CREATE OR REPLACE VIEW :v1.drinking_water AS 
SELECT 
	point_id, amenity,operator, tags, surface, way
	FROM :v1.world_point 
	WHERE ST_WITHIN(way, (SELECT way FROM :v1.Grenzen_Landkreis WHERE Name = :'v2' ORDER BY way_area DESC LIMIT 1))
	AND amenity ='drinking_water';

-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------

CREATE OR REPLACE VIEW :v1.busrouten
 AS
 SELECT :v1.world_line .line_id,
    :v1.world_line .name,
    :v1.world_line .ref,
    :v1.world_line .route,
    :v1.world_line .tags,
    :v1.world_line .way
   FROM :v1.world_line 
  WHERE :v1.world_line .route = 'bus'::text AND st_intersects(:v1.world_line .way, (SELECT way FROM :v1.Grenzen_Landkreis WHERE Name = :'v2' ORDER BY way_area DESC LIMIT 1));

-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------

CREATE OR REPLACE VIEW :v1.fahrradfernwege
 AS
 SELECT :v1.world_line .line_id,
    :v1.world_line .name,
    :v1.world_line .ref,
    :v1.world_line .route,
    :v1.world_line .tags,
    :v1.world_line .way
   FROM :v1.world_line 
  WHERE :v1.world_line .route = 'bicycle'::text 
  AND st_intersects(:v1.world_line .way, (SELECT way FROM :v1.Grenzen_Landkreis WHERE Name = :'v2' ORDER BY way_area DESC LIMIT 1));

-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------

CREATE OR REPLACE VIEW :v1.fahrradwegschilder
 AS
 SELECT :v1.world_point.point_id,
    :v1.world_point.bicycle,
    :v1.world_point.name,
    :v1.world_point.operator,
    :v1.world_point.tourism,
    :v1.world_point.tags,
    :v1.world_point.way
   FROM :v1.world_point
  WHERE :v1.world_point.tourism = 'information'::text 
  AND :v1.world_point.bicycle IS NOT NULL 
  AND st_within(:v1.world_point.way, 
    (SELECT way FROM :v1.Grenzen_Landkreis WHERE Name = :'v2' ORDER BY way_area DESC LIMIT 1)
  );
 

-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------

CREATE OR REPLACE VIEW :v1.baeume AS (
SELECT 
	point_id, 
	osm_id, 
	tags,
	way	
FROM :v1.world_point
  
WHERE "natural" = 'tree'::text 

AND st_within(:v1.world_point.way, 
    (SELECT way FROM :v1.Grenzen_Landkreis WHERE Name = :'v2' ORDER BY way_area DESC LIMIT 1)
 	)
);

-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------

DROP VIEW IF EXISTS :v1.parks;
CREATE OR REPLACE VIEW :v1.parks AS (
SELECT 
    poly_id, 
    osm_id, 
    access, 
    historic,
    landuse,
    leisure,
    name,
    tags, 
    way_area,
    way
FROM :v1.world_polygon
  
WHERE leisure = 'park'::text 

AND st_Intersects(:v1.world_polygon.way, 
    (SELECT way FROM :v1.Grenzen_Landkreis WHERE Name = :'v2' ORDER BY way_area DESC LIMIT 1)
 	)
);

-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------

CREATE OR REPLACE VIEW :v1.parken AS (
SELECT *, 
	CASE
		WHEN parkl_left = 'no' AND parkl_right = 'no' THEN 0
		WHEN parkl_left = 'no' AND parkl_right != 'no' THEN -0.5
		WHEN parkl_left != 'no' AND parkl_right = 'no' THEN -0.5
		ELSE 0
	END as score_parking
FROM (
	SELECT line_id, osm_id, name, highway, surface,
		bicycle, 
		tags -> 'parking:lane' parkl,
		tags -> 'parking:lane:parallel' parkl_para,
		tags -> 'parking:lane:left' parkl_left,
		tags -> 'parking:lane:right' parkl_right,
		way
	FROM :v1.world_line 
	WHERE ST_within(way, 
		(SELECT way FROM :v1.Grenzen_Landkreis WHERE Name = :'v2' ORDER BY way_area DESC LIMIT 1)
					)
	AND (
	tags ? 'parking:lane'
	OR tags ? 'parking:lane:parallel'
	OR tags ? 'parking:lane:left'
	OR tags ? 'parking:lane:right'
	)
) x
);

-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------

DROP MATERIALIZED VIEW IF EXISTS :v1.beleuchtet;
CREATE MATERIALIZED VIEW :v1.beleuchtet AS (
	SELECT line_id, osm_id, name, highway, surface,
		bicycle, 
		tags -> 'lit' as lit,
    1 as score_lit,
		way
	FROM :v1.world_line 
	WHERE ST_within(way, 
		(SELECT way FROM :v1.Grenzen_Landkreis WHERE Name = :'v2' ORDER BY way_area DESC LIMIT 1)
		)
	AND tags -> 'lit' = 'yes'
);

CREATE INDEX beleuchtet_lines_id_idx
 	ON :v1.beleuchtet USING gist
	(way);


-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------