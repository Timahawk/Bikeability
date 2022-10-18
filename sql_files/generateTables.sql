----------------------------------------------------------------------------------------
----- This is the table for cyclosm_ways -----------------------------------------------
----------------------------------------------------------------------------------------
DROP TABLE IF EXISTS :v1.cyclosm_ways CASCADE;
CREATE TABLE :v1.cyclosm_ways (
	road_id integer PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
	line_id integer,
	way geometry,
	type text,
	access text,
	layer text, 
	maxspeed_kmh numeric,
	bicycle text, 
	motor_vehicle text, 
	cyclestreet text,
	oneway text, 
	cycleway_left_render text,
	cycleway_right_render text, 
	cycleway_left_oneway text,
	cycleway_right_oneway text,
	can_bicycle text, 
	segregated text,
	oneway_bicycle text,
	has_ramp text,
	surface_type text,
	service text,
	mtb_scale integer,
	mtb_scale_imba integer,
	name text,
	osm_id integer,
	z_order integer,
	bridge text,
	tunnel text--,
	-- CONSTRAINT line_id_fk
	-- 	FOREIGN KEY(line_id)
	-- 	REFERENCES lines(line_id)
);
-- Index
CREATE INDEX cyclosm_ways_geom_idx
    ON :v1.cyclosm_ways USING gist
    (way)
    TABLESPACE pg_default;

-- Fill TABLE 
INSERT  INTO :v1.cyclosm_ways 
	(line_id, way, type, access,layer,
	maxspeed_kmh, bicycle, motor_vehicle, 
	cyclestreet, oneway, cycleway_left_render, cycleway_right_render, 
	cycleway_left_oneway, cycleway_right_oneway,
	can_bicycle, segregated, oneway_bicycle, has_ramp,
	surface_type,service, mtb_scale, mtb_scale_imba, name, osm_id,
	z_order, bridge, tunnel)
	SELECT
		line_id,
		way,
		COALESCE(
		CASE
			WHEN highway='raceway' THEN 'track'  -- render raceways as tracks
			WHEN highway='road' THEN 'residential'  -- render "road" as residential
			WHEN highway='trunk' THEN 'motorway'  -- trunk as motorway, check can_bicycle if cyclable
			WHEN highway='trunk_link' THEN 'motorway_link'  -- trunk as motorway
			WHEN highway='busway' THEN 'service'  -- busway as service
			WHEN highway='footway' AND (bicycle='yes' OR bicycle='designated') THEN 'path'
			WHEN highway='bridleway' AND (bicycle='yes' OR bicycle='designated') THEN 'path'
			WHEN highway!='bus_guideway' THEN highway
			ELSE NULL
		END,
		CASE
			WHEN railway IN ('light_rail', 'subway', 'narrow_gauge', 'rail', 'tram') THEN 'railway'
			ELSE NULL
		END
		) AS type,
		access,
		layer,
		CASE
			WHEN tags->'maxspeed'~E'^\\d+$' THEN (tags->'maxspeed')::integer
			WHEN tags->'maxspeed'~E'^\\d+ mph$' THEN REPLACE(tags->'maxspeed', ' mph', '')::integer * 1.609344
			WHEN tags->'maxspeed'~E'^\\d+ knots$' THEN REPLACE(tags->'maxspeed', ' knots', '')::integer * 1.852
			WHEN tags->'maxspeed'='walk' THEN 5
			ELSE NULL
		END AS maxspeed_kmh,
		bicycle,
		CASE
			WHEN COALESCE(motorcar, tags->'motor_vehicle', tags->'vehicle', access, 'yes') NOT IN ('no', 'private') THEN 'yes'
			-- goods and hgv don't need COALESCE chains, because the next step would be motorcar, which is checked above
			WHEN tags->'goods' NOT IN ('no', 'private') THEN 'yes'
			WHEN tags->'hgv' NOT IN ('no', 'private') THEN 'yes'
			-- moped and mofa are not checked, since most countries that have separate access controls for them treat them as quasi-bicycles
			WHEN COALESCE(tags->'motorcycle', tags->'motor_vehicle', tags->'vehicle', access, 'yes') NOT IN ('no', 'private') THEN 'yes'
			-- TODO: style psv-only roads slightly differently
			-- bus only needs to have its COALESCE chain go up to psv, because the next step would be motorcar, which is checked above
			WHEN COALESCE(tags->'bus', tags->'psv') NOT IN ('no', 'private') THEN 'psv'
			WHEN tags->'taxi' NOT IN ('no', 'private') THEN 'psv'
			ELSE 'no'
		END AS motor_vehicle,
		CASE
			WHEN tags->'cyclestreet' IN ('yes') THEN 'yes'
			WHEN tags->'bicycle_road' IN ('yes') THEN 'yes'
			ELSE 'no'
		END AS cyclestreet,
		CASE
			WHEN oneway IN ('yes', '-1') THEN oneway
			WHEN junction IN ('roundabout') AND (oneway IS NULL OR NOT oneway IN ('no', 'reversible')) THEN 'yes'
			ELSE 'no'
		END AS oneway,
		CASE
			WHEN tags->'cycleway:left' IN ('track', 'opposite_track') THEN 'track'
			WHEN tags->'sidewalk:left:bicycle' != 'no' AND tags->'sidewalk:left:segregated' = 'yes' THEN 'track'
			WHEN tags->'cycleway:left' IN ('lane', 'opposite_lane') THEN 'lane'
			WHEN tags->'sidewalk:left:bicycle' IN ('designated', 'yes') THEN 'sidewalk'
			WHEN tags->'cycleway:left' IN ('share_busway', 'opposite_share_busway', 'shoulder', 'shared_lane') THEN 'busway'
			WHEN tags->'cycleway:both' IN ('track', 'opposite_track') THEN 'track'
			WHEN tags->'sidewalk:both:bicycle' != 'no' AND tags->'sidewalk:left:segregated' = 'yes' THEN 'track'
			WHEN tags->'cycleway:both' IN ('lane', 'opposite_lane') THEN 'lane'
			WHEN tags->'sidewalk:both:bicycle' IN ('designated', 'yes') THEN 'sidewalk'
			WHEN tags->'cycleway:both' IN ('share_busway', 'opposite_share_busway', 'shoulder', 'shared_lane') THEN 'busway'
			WHEN tags->'cycleway' IN ('track', 'opposite_track') THEN 'track'
			WHEN tags->'cycleway' IN ('lane', 'opposite_lane') THEN 'lane'
			WHEN tags->'cycleway' IN ('share_busway', 'opposite_share_busway', 'shoulder', 'shared_lane') THEN 'busway'
			ELSE NULL
		END AS cycleway_left_render,
		CASE
			WHEN tags->'cycleway:right' IN ('track', 'opposite_track') THEN 'track'
			WHEN tags->'sidewalk:right:bicycle' != 'no' AND tags->'sidewalk:left:segregated' = 'yes' THEN 'track'
			WHEN tags->'cycleway:right' IN ('lane', 'opposite_lane') THEN 'lane'
			WHEN tags->'sidewalk:right:bicycle' IN ('designated', 'yes') THEN 'sidewalk'
			WHEN tags->'cycleway:right' IN ('share_busway', 'opposite_share_busway', 'shoulder', 'shared_lane') THEN 'busway'
			WHEN tags->'cycleway:both' IN ('track', 'opposite_track') THEN 'track'
			WHEN tags->'sidewalk:both:bicycle' != 'no' AND tags->'sidewalk:left:segregated' = 'yes' THEN 'track'
			WHEN tags->'cycleway:both' IN ('lane', 'opposite_lane') THEN 'lane'
			WHEN tags->'sidewalk:both:bicycle' IN ('designated', 'yes') THEN 'sidewalk'
			WHEN tags->'cycleway:both' IN ('share_busway', 'opposite_share_busway', 'shoulder', 'shared_lane') THEN 'busway'
			WHEN tags->'cycleway' IN ('track', 'opposite_track') THEN 'track'
			WHEN tags->'cycleway' IN ('lane', 'opposite_lane') THEN 'lane'
			WHEN tags->'cycleway' IN ('share_busway', 'opposite_share_busway', 'shoulder', 'shared_lane') THEN 'busway'
			ELSE NULL
		END AS cycleway_right_render,
		CASE
			WHEN tags->'cycleway:left:oneway' IS NOT NULL THEN tags->'cycleway:left:oneway'
			WHEN tags->'cycleway:left' IN ('opposite_lane', 'opposite_track', 'opposite_share_busway') THEN '-1'
			WHEN tags->'cycleway' IN ('opposite_lane', 'opposite_track', 'opposite_share_busway') THEN '-1'
			ELSE NULL
		END AS cycleway_left_oneway,
		CASE
			WHEN tags->'cycleway:right:oneway' IS NOT NULL THEN tags->'cycleway:right:oneway'
			WHEN tags->'cycleway:right' IN ('opposite_lane', 'opposite_track', 'opposite_share_busway') THEN '-1'
			WHEN tags->'cycleway' IN ('opposite_lane', 'opposite_track', 'opposite_share_busway') THEN '-1'
			ELSE NULL
		END AS cycleway_right_oneway,
		CASE
			WHEN bicycle IN ('no', 'private', 'use_sidepath') THEN 'no'
			WHEN bicycle IS NOT NULL THEN bicycle
			WHEN tags->'motorroad' IN ('yes') THEN 'no'
			WHEN highway IN ('motorway', 'motorway_link', 'busway') THEN 'no'
			WHEN tags->'vehicle' IN ('no', 'private') THEN 'no'
			WHEN tags->'vehicle' IS NOT NULL THEN tags->'vehicle'
			WHEN access IN ('no', 'private') THEN 'no'
			WHEN access IS NOT NULL THEN access
			ELSE NULL
		END AS can_bicycle,
		CASE
			WHEN tags->'segregated' IN ('yes') THEN 'yes'
			ELSE 'no'
		END AS segregated,
		CASE
			WHEN tags->'oneway:bicycle' IS NOT NULL THEN tags->'oneway:bicycle'
			WHEN highway='cycleway' AND oneway IS NOT NULL THEN oneway
			WHEN tags->'cycleway' IN ('opposite', 'opposite_lane', 'opposite_track', 'opposite_share_busway')
				OR tags->'cycleway:both' IN ('opposite', 'opposite_lane', 'opposite_track', 'opposite_share_busway')
				OR tags->'cycleway:left' IN ('opposite', 'opposite_lane', 'opposite_track', 'opposite_share_busway')
				OR tags->'cycleway:right' IN ('opposite', 'opposite_lane', 'opposite_track', 'opposite_share_busway')
				OR tags->'cycleway:left:oneway'='-1' OR tags->'cycleway:right:oneway'='-1'
				THEN 'no'
			ELSE NULL
		END AS oneway_bicycle,
		COALESCE(
			tags->'ramp:bicycle',
			tags->'ramp:stroller',
			tags->'ramp:wheelchair',
			tags->'ramp:luggage'
		) AS has_ramp,
		CASE
			-- From best tag to less precise quality surface tag (smoothness > track > surface).
			WHEN tags->'smoothness' IS NULL AND tracktype IS NULL AND surface IS NULL
				THEN 'unknown'
			WHEN tags->'smoothness' IN ('horrible', 'very_horrible', 'impassable')
				THEN 'mtb'
			WHEN tags->'smoothness' IN ('bad', 'very_bad')
				THEN 'cyclocross'
			WHEN tags->'smoothness' IN ('excellent', 'good', 'intermediate')
				THEN 'road'
			WHEN tracktype IN ('grade4', 'grade5')
				THEN 'mtb'
			WHEN tracktype IN ('grade2', 'grade3')
				THEN 'cyclocross'
			WHEN tracktype IN ('grade1')
				THEN 'road'
			WHEN surface IN ('pebblestone', 'dirt', 'earth', 'grass', 'grass_paver', 'gravel_turf', 'ground', 'mud', 'sand')
				THEN 'mtb'
			WHEN surface IN ('concrete:lanes', 'concrete:plates', 'gravel', 'sett', 'unhewn_cobblestone', 'cobblestone', 'wood', 'compacted', 'fine_gravel', 'woodchips')
				THEN 'cyclocross'
			WHEN surface IN ('paved', 'asphalt', 'concrete', 'paving_stones')
				THEN 'road'
			ELSE 'unknown'
		END AS surface_type,
		CASE
			WHEN service in ('parking_aisle', 'drive-through', 'driveway', 'spur', 'siding', 'yard') THEN 'minor'
			ELSE service
		END AS service,
		CASE
			WHEN tags->'mtb:scale'~E'^\\d+[+-]?$' THEN REPLACE(REPLACE(tags->'mtb:scale', '+', ''), '-', '')::integer
			ELSE NULL
		END AS mtb_scale,
		CASE
			WHEN tags->'mtb:scale:imba'~E'^\\d+$' THEN (tags->'mtb:scale:imba')::integer
			ELSE NULL
		END AS mtb_scale_imba,
		name,
		osm_id,
		CASE
			WHEN highway='cycleway' OR (highway IN ('path', 'footway', 'pedestrian', 'bridleway') AND bicycle IN ('yes', 'designated')) THEN CASE WHEN layer~E'^\\d+$' THEN 100*layer::integer+199 ELSE 199 END
			WHEN highway IN ('path', 'footway', 'pedestrian', 'bridleway') THEN CASE WHEN layer~E'^\\d+$' THEN 100*layer::integer+198 ELSE 198 END
			ELSE z_order
		END AS z_order,
		bridge,
		COALESCE(
			tunnel,
			covered,
			tags->'indoor'
		) AS tunnel
	FROM :v1.world_line
	WHERE (railway IN ('light_rail', 'subway', 'narrow_gauge', 'rail', 'tram')
		OR highway IS NOT NULL)
	AND ST_INTERSECTS(way, (SELECT way FROM :v1.Grenzen_Landkreis WHERE Name = :'v2' ORDER BY way_area DESC LIMIT 1))
	ORDER BY z_order ASC;


----------------------------------------------------------------------------------------
------ This is the table for the nodes -------------------------------------------------
----------------------------------------------------------------------------------------
DROP TABLE IF Exists :v1.nodes CASCADE;
CREATE TABLE :v1.nodes (
	node_id integer PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
	geom geometry
);
-- Index
CREATE INDEX nodes_geom_idx
    ON :v1.nodes USING gist
    (geom)
;
-- Fill Table
-- Seems to insert also lines and multipoints. Should be looked into
INSERT INTO :v1.nodes (geom)
	WITH unique_nodes (id, geom) AS (
		SELECT
			row_number() OVER (PARTITION BY ST_AsBinary(geom)) AS id,
			geom
		FROM (
		SELECT row_number() OVER () AS node_id,
			ST_Intersection(a.way, b.way) as geom
		FROM
			:v1.cyclosm_ways as a,
			:v1.cyclosm_ways as b
		WHERE
			st_Intersects(a.way, b.way)
		AND 
			a.road_id != b.road_id
		) X
	)
	SELECT
		-- row_number() over() as node_id,
		geom
	FROM
		unique_nodes 
	WHERE
		id=1
	AND ST_GeometryType(geom) = 'ST_Point'
	UNION

	SELECT 
		ST_Snap(
			y.geom, 
			(SELECT way FROM :v1.cyclosm_ways WHERE ST_Distance(geom, way) < 0.01 LIMIT 1),
			0.01) 
	FROM (
		SELECT
		-- row_number() over() as node_id,
		(ST_Dump(geom)).geom as geom
	FROM
		unique_nodes 
	WHERE
		id=1
	AND ST_GeometryType(geom) = 'ST_MultiPoint'
	) Y;


----------------------------------------------------------------------------------------
------ This is the table that is used for roadsegments. --------------------------------
----------------------------------------------------------------------------------------
DROP TABLE IF exists :v1.roadsegs CASCADE;
CREATE TABLE :v1.roadsegs (
	road_id integer,
	seg_id integer PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
	line_id integer,
	geom geometry,
	len numeric,
	straightness numeric,
	road_type text,
	CONSTRAINT roadseg_fk
		FOREIGN KEY(road_id)
			REFERENCES :v1.cyclosm_ways(road_id)
);
CREATE INDEX IF NOT EXISTS roadsegs_geom_idx
    ON :v1.roadsegs USING gist
    (geom)
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS roadsegs_road_id_idx
    ON :v1.roadsegs USING btree
    (road_id ASC NULLS LAST)
    TABLESPACE pg_default;


CREATE INDEX IF NOT EXISTS roadsegs_seg_id_idx
    ON :v1.roadsegs USING btree
    (seg_id ASC NULLS LAST)
    TABLESPACE pg_default;

---Fill all Values into the road segments. (15 min) --------------------------
-- Must be done so that route segments can be assositated successfully.
-- Taken from --
-- https://gis.stackexchange.com/questions/332213/splitting-lines-with-points-using-postgis --
INSERT INTO :v1.roadsegs (road_id, seg_id, line_id, geom, len, straightness, road_type)
	SELECT road_id,
		row_number() over() as seg_id,
		line_id, 
		geom,
		ST_Length(ST_Transform(geom, 4647)) as len, 
		CASE 
			WHEN ST_Distance(
				ST_Transform(ST_StartPoint(geom),4647), 
				ST_Transform(ST_Endpoint(geom), 4647))  = 0 THEN 0 
			ELSE round((ST_Distance(
				ST_Transform(ST_StartPoint(geom),4647), 
				ST_Transform(ST_Endpoint(geom), 4647))/ST_Length(ST_Transform(geom, 4647)) * 100)::numeric, 2)
		END as straightness,
		type
		FROM (
		SELECT road_id,
				line_id,
			(ST_Dump(ST_Split(
				ST_Snap(a.way, (SELECT ST_Collect(b.geom) AS geom FROM :v1.nodes AS b WHERE ST_Intersects(a.way, b.geom)), 0.001),
				(SELECT ST_Collect(b.geom) AS geom FROM :v1.nodes AS b WHERE ST_Intersects(a.way, b.geom)) 
			))).geom,
			type
		FROM   :v1.cyclosm_ways AS a
		UNION ALL
		SELECT road_id,
				line_id,
			way,
			type
		FROM   :v1.cyclosm_ways AS a
		WHERE NOT EXISTS (
		SELECT 1
		FROM   :v1.nodes AS b
		WHERE  ST_Intersects(a.way, b.geom)
		)
	) X;

----------------------------------------------------------------------------------------
------ This are more filterd approach to nodes for the intersections -------------------
----------------------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS :v1.nodes_limited;
CREATE MATERIALIZED VIEW :v1.nodes_limited AS (
	SELECT * FROM (
		SELECT n.*, count(*), array_agg(w.road_type) as types
		FROM :v1.nodes n
		JOIN :v1.roadsegs w
		ON ST_Intersects(ST_Buffer(n.geom, 1), w.geom)
		GROUP BY node_id
	) x
	-- Weil dann is ja auch keine kreuzung
	WHERE count > 2
	-- Weil footpath mit footpath is jetzt net so wichtig.
	AND types && array['residential', 'tertiary', 'cycleway', 'secondary', 'tertiary_link', 'secondary_link','motorway', 'railway']
	-- removed so einseitige einfallsstraßen aber keine kreuzungen.
	AND NOT (count = 3 AND types && array['service', 'footpath', 'path']
	));

----------------------------------------------------------------------------------------
------ This is the table that is used for the intersections. .--------------------------
----------------------------------------------------------------------------------------
DROP TABLE IF EXISTS :v1.intersections;
CREATE TABLE :v1.intersections
(
    intersection_id integer,
	traffic_lights text,
	crossings text,
	rails text,
	railway_crossing text,
	bus text, 
	fahrradwegeschilder text,
	road_types text[],
	seg_ids text[],
	cnt integer,
	score_intersection float,
    geom geometry,
    PRIMARY KEY (intersection_id)
);

CREATE INDEX intersections_id_idx
    ON :v1.intersections USING btree
    (intersection_id);

CREATE INDEX intersections_geom_idx
    ON :v1.intersections USING gist
    (geom);

INSERT INTO :v1.intersections (intersection_id, traffic_lights, crossings, rails, railway_crossing,
		bus, fahrradwegeschilder, road_types, seg_ids, cnt, geom, score_intersection)
	WITH forms AS 
	(SELECT
		(ST_Dump(
			ST_Union(
				ST_Buffer(geom, 15)
			)
		)).geom as geom 
		FROM :v1.nodes_limited),
		
	intersections_plus_roads AS (
	SELECT
		row_number() over() as intersection_id,
		CASE
			WHEN ST_Intersects(
				(SELECT ST_Collect(way) FROM :v1.traffic_lights),
				i.geom) THEN 'yes'
		ELSE 'no'
		END as traffic_lights,
		CASE 
			WHEN ST_Intersects(
				(SELECT ST_Collect(way) FROM :v1.crossings),
				i.geom) THEN 'yes'
			ELSE 'no'
		END as crossings,
		CASE
			WHEN ST_Intersects(
				(SELECT ST_Collect(way) FROM :v1.railway),
				i.geom) THEN 'yes'
			ELSE 'no'
		END as rails,
		CASE
			WHEN ST_Intersects(
				(SELECT ST_Collect(way) FROM :v1.railway_crossings),
				i.geom) THEN 'yes'
			ELSE 'no'
		END as railway_crossing,
		CASE
			WHEN ST_Intersects(
				(SELECT ST_Collect(way) FROM :v1.busrouten),
				i.geom) THEN 'yes'
			ELSE 'no'
		END as bus,
		CASE
			WHEN ST_Intersects(
				(SELECT ST_Collect(way) FROM :v1.fahrradwegschilder),
				i.geom) THEN 'yes'
			ELSE 'no'
		END as fahrradwegeschilder,
	-- 	rs.road_type,
	-- 	rs.seg_id,
		i.geom
		FROM forms i
	-- 	WHERE ST_Intersects(rs.geom, i.geom)
	), summary AS (
	SELECT 
		ipr.intersection_id,
		ipr.traffic_lights,
		ipr.crossings,
		ipr.rails,
		ipr.railway_crossing,
		ipr.bus, 
		ipr.fahrradwegeschilder,
		Array_agg(rs.road_type) as road_types,
		Array_agg(rs.seg_id) as seg_ids,
		count(rs.road_type) as cnt,
		ipr.geom
	FROM intersections_plus_roads ipr, :v1.roadsegs rs
	WHERE ST_Intersects(rs.geom, ipr.geom)
	GROUP BY 
		intersection_id,
		ipr.intersection_id,
		ipr.traffic_lights,
		ipr.crossings,
		ipr.rails,
		ipr.railway_crossing,
		ipr.bus, 
		ipr.fahrradwegeschilder,
		ipr.geom
	)
		SELECT *,
		CASE
			WHEN traffic_lights = 'yes' THEN 1
			WHEN crossings = 'yes' THEN 0.75
			WHEN 'secondary'= ANY(road_types) THEN -1
			WHEN 'tertiary'= ANY(road_types) THEN -1
			WHEN 'primary'= ANY(road_types) THEN -1
			WHEN railway_crossing = 'yes ' THEN -0.5
			WHEN bus = 'yes' THEN -0.5
		ELSE 0
		END as score_intersection

	FROM summary
	;

----------------------------------------------------------------------------------------
------ This is the table that is used for the parallel Lines. --------------------------
----------------------------------------------------------------------------------------
DROP TABLE IF exists :v1.roadseg_parallel_raillines CASCADE;
CREATE Table :v1.roadseg_parallel_raillines (
	road_id integer,
    seg_id integer,
    line_id integer,
    geom geometry,
    len numeric,
    straightness numeric,
    road_type text,
	parallel_id integer GENERATED BY DEFAULT AS IDENTITY, 
	CONSTRAINT roadseg_fk
	FOREIGN KEY(road_id)
		REFERENCES :v1.cyclosm_ways(road_id),
	CONSTRAINT segment_fk
	FOREIGN KEY(seg_id)
		REFERENCES :v1.roadsegs(seg_id)--,
	-- CONSTRAINT line_fk
	-- FOREIGN KEY(line_id)
	-- 	REFERENCES lines(line_id)
);



INSERT INTO :v1.roadseg_parallel_raillines (seg_id, road_id,  line_id, geom, len, straightness, road_type)
	SELECT DISTINCT seg_id, road_id,  line_id, geom, len, straightness, road_type FROM (
		SELECT road_id, seg_id, line_id, geom, len, straightness, road_type
		FROM
			(
			SELECT s.*, r.road_id as rail, r.geom as railGeom,
				degrees(ST_Angle(ST_SetSRID('POINT(0 0)'::geometry, 3857), ST_StartPoint(s.geom), ST_EndPoint(s.geom))) as degX,
				degrees(ST_Angle(ST_SetSRID('POINT(0 0)'::geometry, 3857), ST_StartPoint(r.geom), ST_EndPoint(r.geom))) as dexRail
			FROM :v1.roadsegs s, :v1.roadsegs r
			WHERE
				s.road_type != 'railway'
			AND 
				r.road_type = 'railway'
			AND
				ST_Intersects(
					(ST_Buffer(r.geom, 3)),
					s.geom)
			) X
		WHERE abs(degX - dexRail) < 45
	) Y;

----------------------------------------------------------------------------------------
------ This is the table that is used for the Routes. ----------------------------------
----------------------------------------------------------------------------------------
DROP TABLE IF exists :v1.routes CASCADE;
CREATE TABLE :v1.routes (
	route_id integer PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
    start bigint,
	startlat numeric,
	startlon numeric,
    dest bigint,
	destlat numeric,
	destlon numeric,
    -- dist numeric,
	length numeric,
	straightline_length numeric,
	track_length numeric,
	filtered_ascend numeric,
	plain_ascend numeric,
	total_time numeric,
	total_energy numeric,
	cost  numeric,
	fastest_track_length numeric, 
	car_total_time numeric,
    geom geometry
	-- CONSTRAINT routes_pk PRIMARY KEY (start, dest)
);

CREATE INDEX IF NOT EXISTS routes_id_idx
    ON :v1.routes USING btree
    (route_id ASC NULLS LAST)
    TABLESPACE pg_default;

ALTER TABLE IF EXISTS :v1.routes
    CLUSTER ON routes_id_idx;


CREATE INDEX IF NOT EXISTS routes_geom_idx
    ON :v1.routes USING gist
    (geom)
    TABLESPACE pg_default;


----------------------------------------------------------------------------------------
------ This is the table that is used for the route Segments. --------------------------
----------------------------------------------------------------------------------------
DROP TABLE IF exists :v1.route_segments;
CREATE TABLE :v1.route_segments (
	route_id integer,
    start integer ,
    dest integer,
    road_id integer,
	seg_id integer,
	line_id integer,
	geom geometry,
    len numeric,
	part integer,
	CONSTRAINT route_segments_pk PRIMARY KEY (start, dest, seg_id)
);

CREATE INDEX IF NOT EXISTS route_id_idx
    ON :v1.route_segments USING btree
    (route_id ASC NULLS LAST)
    TABLESPACE pg_default;

ALTER TABLE IF EXISTS :v1.route_segments
    CLUSTER ON route_id_idx;


CREATE INDEX IF NOT EXISTS route_seg_geom_idx
    ON :v1.route_segments USING gist
    (geom)
    TABLESPACE pg_default;

-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------

CREATE OR REPLACE VIEW :v1.used_destinations AS
SELECT r.route_id, d.way
FROM :v1.routes r
JOIN :v1.destinations d 
ON r.dest = d.dest_id;

-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------

CREATE OR REPLACE VIEW :v1.used_starts AS
SELECT r.route_id, d.way
FROM :v1.routes r
JOIN :v1.destinations d 
ON r.start = d.dest_id;


-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------
CREATE VIEW :v1.intersections2 AS (

WITH forms AS 
(SELECT
	(ST_Dump(
		ST_Union(
			ST_Buffer(geom, 15)
		)
	)).geom as geom 
	FROM :v1.nodes_limited),

intersections_plus_roads AS (
SELECT
	row_number() over() as intersection_id,
	CASE
		WHEN ST_Intersects(
			(SELECT ST_Collect(way) FROM :v1.traffic_lights),
			i.geom) THEN 'yes'
	ELSE 'no'
	END as traffic_lights,
	CASE 
		WHEN ST_Intersects(
			(SELECT ST_Collect(way) FROM :v1.crossings),
			i.geom) THEN 'yes'
		ELSE 'no'
	END as crossings,
	CASE
		WHEN ST_Intersects(
			(SELECT ST_Collect(way) FROM :v1.railway),
			i.geom) THEN 'yes'
		ELSE 'no'
	END as rails,
	CASE
		WHEN ST_Intersects(
			(SELECT ST_Collect(way) FROM :v1.railway_crossings),
			i.geom) THEN 'yes'
		ELSE 'no'
	END as railway_crossing,
	CASE
		WHEN ST_Intersects(
			(SELECT ST_Collect(way) FROM :v1.busrouten),
			i.geom) THEN 'yes'
		ELSE 'no'
	END as bus,
	CASE
		WHEN ST_Intersects(
			(SELECT ST_Collect(way) FROM :v1.fahrradwegschilder),
			i.geom) THEN 'yes'
		ELSE 'no'
	END as fahrradwegeschilder,
-- 	rs.road_type,
-- 	rs.seg_id,
	i.geom
	FROM forms i
-- 	WHERE ST_Intersects(rs.geom, i.geom)
),
summary AS ( 
	SELECT 
		ipr.intersection_id,
		ipr.traffic_lights,
		ipr.crossings,
		ipr.rails,
		ipr.railway_crossing,
		ipr.bus, 
		ipr.fahrradwegeschilder,
		Array_agg(rs.road_type) as road_types,
		Array_agg(rs.seg_id) as seg_ids,
		count(rs.road_type) as cnt,
		ipr.geom
	FROM intersections_plus_roads ipr, :v1.roadsegs rs
	WHERE ST_Intersects(rs.geom, ipr.geom)
	GROUP BY 
		intersection_id,
		ipr.intersection_id,
		ipr.traffic_lights,
		ipr.crossings,
		ipr.rails,
		ipr.railway_crossing,
		ipr.bus, 
		ipr.fahrradwegeschilder,
		ipr.geom
	)
SELECT *,
	CASE
		WHEN traffic_lights = 'yes' THEN 1
		WHEN crossings = 'yes' THEN 0.75
		WHEN 'secondary'= ANY(road_types) THEN -1
		WHEN 'tertiary'= ANY(road_types) THEN -1
		WHEN 'primary'= ANY(road_types) THEN -1
		WHEN railway_crossing = 'yes ' THEN -1
		WHEN bus = 'yes' THEN -1
	ELSE 0
	END as score_intersection

FROM summary
	)
;
-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------