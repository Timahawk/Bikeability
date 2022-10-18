
------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------


DROP VIEW IF EXISTS :v1.roadsegs_extended CASCADE;
CREATE VIEW :v1.roadsegs_extended AS (

WITH routesegs_grouped AS (
	SELECT route_segments.seg_id,
	count(*) AS count
	FROM :v1.route_segments
	GROUP BY route_segments.seg_id
), 

n_trees AS (
	SELECT roadsegs.seg_id,
	count(*) AS treecnt
	FROM :v1.roadsegs
		JOIN :v1.baeume ON ST_Intersects(st_buffer(baeume.way, 10::double precision), roadsegs.geom)
	GROUP BY roadsegs.seg_id
), 

along_parks AS (
	SELECT roadsegs.seg_id,
	1 AS score_park
	FROM :v1.roadsegs
		JOIN :v1.parks ON st_intersects(st_buffer(parks.way, 10::double precision), roadsegs.geom)
	GROUP BY roadsegs.seg_id
), 

busrouten AS (
	SELECT roadsegs.seg_id,
	'-1'::integer AS score_parallel_busline
	FROM :v1.roadsegs
	WHERE st_contains(( SELECT st_union(st_buffer(busrouten.way, 1::double precision)) AS st_union
			FROM :v1.busrouten), roadsegs.geom)
), 

fahrradfernwege AS (
	SELECT roadsegs.seg_id,
	1 AS score_fahrradfernwege
	FROM :v1.roadsegs
	WHERE st_contains(( SELECT st_union(st_buffer(fahrradfernwege.way, 1::double precision)) AS st_union
			FROM :v1.fahrradfernwege), roadsegs.geom)
), 

parallels AS (
	SELECT DISTINCT ON (roadseg_parallel_raillines.seg_id) 
		roadseg_parallel_raillines.seg_id,
		roadseg_parallel_raillines.parallel_id 
	FROM :v1.roadseg_parallel_raillines
),

x as ( 
	SELECT 
		rs.seg_id,
		rs.road_id,
		rs.line_id,
		rs.len,
		rs.straightness,
			CASE
				WHEN rs.straightness > 90::numeric THEN 1::numeric
				WHEN rs.straightness > 80::numeric THEN 0.5
				WHEN rs.straightness > 60::numeric THEN 0::numeric
				WHEN rs.straightness > 40::numeric THEN '-0.5'::numeric
				ELSE '-1'::integer::numeric
			END AS score_straightness,
		rsg.count,
		ways.type,
		ways.can_bicycle,
		ways.cycleway_left_render,
		ways.cycleway_right_render,
			CASE
				WHEN ways.can_bicycle = 'designated'::text THEN 'designated'::text
				WHEN ways.cycleway_left_render = 'track'::text THEN 'designated'::text
				WHEN ways.cycleway_left_render IS NOT NULL THEN 'bikelane'::text
				WHEN ways.cycleway_right_render = 'track'::text THEN 'designated'::text
				WHEN ways.cycleway_right_render IS NOT NULL THEN 'bikelane'::text
				WHEN ways.type = 'cycleway'::text THEN 'designated'::text
				WHEN ways.type = ANY (ARRAY['motorway'::text, 'motorway_link'::text, 'primary'::text, 'primary_link'::text, 'secondary'::text, 'secondary_link'::text, 'steps'::text, 'railway'::text]) THEN 'none'::text
				WHEN ways.type = 'pedestrian'::text THEN 'pedestrian'::text
				WHEN ways.type = ANY (ARRAY['tertiary'::text, 'tertiary_link'::text]) THEN 'none'::text
				ELSE 'none'::text
			END AS infrastructure,
			CASE
				WHEN ways.can_bicycle = 'no'::text THEN '-1'::integer
				WHEN ways.can_bicycle = ANY (ARRAY['designated'::text, 'yes'::text, 'destination'::text, 'permissive'::text, 'customers'::text, 'agricultural'::text, 'shared'::text, 'forestry'::text]) THEN 0
				WHEN ways.can_bicycle IS NULL THEN 0
				ELSE 0
			END AS score_permissions,
			CASE
				WHEN ways.surface_type = 'road'::text THEN 0::numeric
				WHEN ways.surface_type = 'cyclocross'::text THEN '-0.2'::numeric
				WHEN ways.surface_type = 'mtb'::text THEN '-1'::integer::numeric
				ELSE '-0.2'::numeric
			END AS score_surface,
			CASE
				WHEN ways.can_bicycle = 'designated'::text THEN 1::numeric
				WHEN ways.maxspeed_kmh <= 30::numeric THEN 1::numeric
				WHEN ways.maxspeed_kmh <= 40::numeric THEN 0.5
				WHEN ways.maxspeed_kmh <= 50::numeric THEN 0::numeric
				WHEN ways.maxspeed_kmh <= 60::numeric THEN '-0.2'::numeric
				WHEN ways.maxspeed_kmh <= 70::numeric THEN '-0.4'::numeric
				WHEN ways.maxspeed_kmh <= 80::numeric THEN '-0.6'::numeric
				WHEN ways.maxspeed_kmh <= 90::numeric THEN '-0.8'::numeric
				WHEN ways.maxspeed_kmh <= 100::numeric THEN '-1'::integer::numeric
				ELSE 0::numeric
			END AS score_maxspeed,
			CASE
				WHEN ways.can_bicycle = 'designated'::text THEN 1::numeric
				WHEN ways.cycleway_left_render = 'track'::text THEN 1::numeric
				WHEN ways.cycleway_left_render IS NOT NULL THEN 0.7
				WHEN ways.cycleway_right_render = 'track'::text THEN 1::numeric
				WHEN ways.cycleway_right_render IS NOT NULL THEN 0.7
				WHEN ways.type = 'cycleway'::text THEN 1::numeric
				WHEN ways.type = ANY (ARRAY['motorway'::text, 'motorway_link'::text, 'primary'::text, 'primary_link'::text, 'secondary'::text, 'secondary_link'::text, 'steps'::text, 'railway'::text]) THEN '-1'::integer::numeric
				WHEN ways.type = 'pedestrian'::text THEN 0::numeric
				WHEN ways.type = ANY (ARRAY['tertiary'::text, 'tertiary_link'::text]) THEN '-0.7'::numeric
				ELSE 0::numeric
			END AS score_infrastructure,
			CASE
				WHEN ways.can_bicycle = 'designated'::text THEN 0
				WHEN ways.cycleway_left_render IS NOT NULL THEN 0
				WHEN ways.cycleway_right_render IS NOT NULL THEN 0
				WHEN parallels.parallel_id IS NOT NULL THEN '-1'::integer
				ELSE 0
			END AS score_parallel_rail,
			COALESCE(bus.score_parallel_busline, 0) AS score_parallel_busline,
			COALESCE(trees.treecnt, 0::bigint) AS treecnt,
			CASE
				WHEN trees.treecnt > 10 THEN 1::numeric
				WHEN trees.treecnt > 5 THEN 0.75
				WHEN trees.treecnt > 3 THEN 0.5
				WHEN trees.treecnt > 1 THEN 0.25
				ELSE 0::numeric
			END AS score_treecnt,
			COALESCE(parks.score_park, 0) AS score_park,
			COALESCE(parking.score_parking, 0::numeric) AS score_parking,
			COALESCE(rad.score_fahrradfernwege, 0) AS score_fahrradfernwege,
			COALESCE(lit.score_lit, 0) AS score_lit,
			rs.geom
	FROM :v1.roadsegs rs
		LEFT JOIN routesegs_grouped rsg 		ON rs.seg_id = rsg.seg_id
		LEFT JOIN n_trees trees 				ON rs.seg_id = trees.seg_id
		LEFT JOIN along_parks parks 			ON rs.seg_id = parks.seg_id
		LEFT JOIN :v1.parken parking 		ON rs.line_id = parking.line_id
		LEFT JOIN busrouten bus 				ON rs.seg_id = bus.seg_id
		LEFT JOIN fahrradfernwege rad 			ON rs.seg_id = rad.seg_id
		LEFT JOIN :v1.beleuchtet lit 		ON rs.line_id = lit.line_id
		LEFT JOIN parallels 					ON rs.seg_id = parallels.seg_id
		LEFT JOIN :v1.cyclosm_ways ways	ON rs.road_id = ways.road_id
	)

SELECT
	x.seg_id,
	x.road_id,
	x.line_id,
	x.len,
	x.geom,
	x.straightness,
	x.score_straightness,
	x.count,
	x.type,
	x.can_bicycle,
	x.cycleway_left_render,
	x.cycleway_right_render,
	x.infrastructure,
	x.score_permissions,
	x.score_surface,
	x.score_maxspeed,
	x.score_infrastructure,
	x.score_parallel_rail,
	x.score_parallel_busline,
	x.treecnt,
	x.score_treecnt,
	x.score_park,
	x.score_parking,
	x.score_fahrradfernwege,
	x.score_lit,
	(
		(x.score_permissions * 1)::numeric + 
		x.score_surface * 4::numeric + 
		x.score_maxspeed * 5::numeric + 
		x.score_infrastructure * 7::numeric + 
		(x.score_parallel_rail * 5)::numeric + 
		(x.score_parallel_busline * 3)::numeric + 
		(x.score_fahrradfernwege * 2)::numeric + 
		x.score_straightness * 2::numeric + 
		x.score_treecnt * 3::numeric + 
		(x.score_park * 4)::numeric + 
		x.score_parking * 5::numeric + 
		(x.score_lit * 2)::numeric
	) / 43::numeric AS score
FROM  x
);


------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------

-- SELECT 
-- 	avg(score_permissions) as permission,
-- 	avg(score_surface) as surface,
-- 	avg(score_maxspeed) as maxspeed,
-- 	avg(score_infrastructure) as infrastructure,
-- 	avg(score_parallel_rail) as parallel_rail,
-- 	avg(score_parallel_busline) as parallel_bus,
-- 	avg(score_treecnt) as trees, 
-- 	avg(score_park) as park,
-- 	avg(score_parking) as parking,
-- 	avg(score_fahrradfernwege) as fahrradfernwege,
-- 	avg(score_lit) as lit,
-- 	avg(score)
-- FROM :v1.roadsegs_extended;

------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------

DROP VIEW IF EXISTS :v1.routes_extended;
CREATE VIEW :v1.routes_extended AS (
with  rs_plus_length AS (
	SELECT rs.*, r.length FROM :v1.route_segments rs JOIN :v1.routes r ON rs.route_id = r.route_id  
), summarize_routesegs AS (
         SELECT rs.route_id,
            sum(rse.len) AS length,
            sum(rse.score_permissions::numeric * rse.len / rs.length) AS permissions,
            sum(rse.score_surface * rse.len / rs.length) AS surface,
            sum(rse.score_maxspeed * rse.len / rs.length) AS maxspeed,
            sum(rse.score_infrastructure * rse.len / rs.length) AS infrastructure,
            sum(rse.score_parallel_rail::numeric * rse.len / rs.length) AS parallel_rail,
            sum(rse.score_parallel_busline::numeric * rse.len / rs.length) AS parallel_bus,
            sum(rse.score_fahrradfernwege::numeric * rse.len / rs.length) AS fahrradfernwege,
            sum(rse.score_straightness * rse.len / rs.length) AS segment_straigthness,
            sum(rse.score_treecnt * rse.len / rs.length) AS treecnt,
            sum(rse.score_park::numeric * rse.len / rs.length) AS park,
            sum(rse.score_parking * rse.len / rs.length) AS parking,
            sum(rse.score_lit::numeric * rse.len / rs.length) AS lit
           FROM rs_plus_length rs
             JOIN :v1.roadsegs_extended rse ON rs.seg_id = rse.seg_id
          GROUP BY rs.route_id
        ), more1 AS (
         SELECT r.route_id,
            r.start,
            r.startlat,
            r.startlon,
            r.dest,
            r.destlat,
            r.destlon,
            r.length,
            r.straightline_length,
            r.track_length,
            r.filtered_ascend,
            r.plain_ascend,
            r.total_time,
            r.total_energy,
            r.cost,
            r.fastest_track_length,
            r.car_total_time,
            r.geom,
                CASE
                    WHEN st_distance(st_transform(st_startpoint(r.geom), 4647), st_transform(st_endpoint(r.geom), 4647)) = 0::double precision THEN 0::numeric
                    ELSE round((st_distance(st_transform(st_startpoint(r.geom), 4647), st_transform(st_endpoint(r.geom), 4647)) / st_length(st_transform(r.geom, 4647)) * 100::double precision)::numeric, 2)
                END AS straightness,
            r.total_time / r.car_total_time AS rel_time,
            r.track_length / r.fastest_track_length AS rel_length,
            srs.permissions,
            srs.surface,
            srs.maxspeed,
            srs.infrastructure,
            srs.parallel_rail,
            srs.parallel_bus,
            srs.fahrradfernwege,
            srs.segment_straigthness,
            srs.treecnt,
            srs.park,
            srs.parking,
            srs.lit,
                CASE
                    WHEN st_intersects(st_buffer(st_endpoint(r.geom), 50::double precision), ( SELECT st_collect(bicycle_parking.way) AS st_collect
                       FROM :v1.bicycle_parking)) THEN 1::numeric
                    WHEN st_intersects(st_buffer(st_endpoint(r.geom), 100::double precision), ( SELECT st_collect(bicycle_parking.way) AS st_collect
                       FROM :v1.bicycle_parking)) THEN 0.5
                    ELSE 0::numeric
                END AS bicycle_parking,
                CASE
                    WHEN st_intersects(st_buffer(r.geom, 50::double precision), ( SELECT st_collect(drinking_water.way) AS st_collect
                       FROM :v1.drinking_water)) THEN 1::numeric
                    WHEN st_intersects(st_buffer(r.geom, 100::double precision), ( SELECT st_collect(drinking_water.way) AS st_collect
                       FROM :v1.drinking_water)) THEN 0.5
                    ELSE 0::numeric
                END AS drinking_water,
                CASE
                    WHEN st_intersects(st_buffer(st_endpoint(r.geom), 250::double precision), ( SELECT st_collect(bicycle_rental.way) AS st_collect
                       FROM :v1.bicycle_rental)) AND st_intersects(st_buffer(st_startpoint(r.geom), 250::double precision), ( SELECT st_collect(bicycle_rental.way) AS st_collect
                       FROM :v1.bicycle_rental)) THEN 1
                    ELSE 0
                END AS bicycle_rental
           FROM :v1.routes r
             JOIN summarize_routesegs srs ON r.route_id = srs.route_id
        )
 SELECT more1.route_id,
    more1.start,
    more1.startlat,
    more1.startlon,
    more1.dest,
    more1.destlat,
    more1.destlon,
    more1.length,
    more1.straightline_length,
    more1.track_length,
    more1.filtered_ascend,
    more1.plain_ascend,
    more1.total_time,
    more1.total_energy,
    more1.cost,
    more1.fastest_track_length,
    more1.car_total_time,
    more1.geom,
    more1.straightness,
    more1.rel_time,
    more1.rel_length,
    more1.permissions,
    more1.surface,
    more1.maxspeed,
    more1.infrastructure,
    more1.parallel_rail,
    more1.parallel_bus,
    more1.fahrradfernwege,
    more1.segment_straigthness,
    more1.treecnt,
    more1.park,
    more1.parking,
    more1.lit,
    more1.bicycle_parking,
    more1.drinking_water,
    more1.bicycle_rental,
        CASE
            WHEN more1.rel_time > 0::numeric AND more1.rel_time < 1.25 THEN 0::numeric
            WHEN more1.rel_time < 0::numeric THEN 1::numeric
            WHEN more1.rel_time > 1.25 AND more1.rel_time < 1.5 THEN '-0.25'::numeric
            WHEN more1.rel_time > 1.5 AND more1.rel_time < 2::numeric THEN '-0.5'::numeric
            WHEN more1.rel_time > 2::numeric THEN '-1'::integer::numeric
            ELSE 0::numeric
        END AS time_vs_car,
        CASE
            WHEN more1.rel_length < 1.2 THEN 0::numeric
            WHEN more1.rel_length < 1.4 THEN '-0.2'::numeric
            WHEN more1.rel_length < 1.6 THEN '-0.4'::numeric
            WHEN more1.rel_length < 1.8 THEN '-0.6'::numeric
            ELSE '-1'::integer::numeric
        END AS len_vs_shortest,
        CASE
            WHEN more1.straightness > 90::numeric THEN 1::numeric
            WHEN more1.straightness > 80::numeric THEN 0.5
            WHEN more1.straightness > 60::numeric THEN 0::numeric
            WHEN more1.straightness > 40::numeric THEN '-0.5'::numeric
            ELSE '-1'::integer::numeric
        END AS straigthness_score
   FROM more1
);

------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------
DROP VIEW IF Exists :'v1'.bikeabiltiy;
CREATE VIEW :'v1'.bikeabiltiy AS ( 
SELECT 
	:'v1' as name,
	count(*) as route_included,
	avg(permissions) as permissions, 
	avg(surface)as  surface,
	avg(maxspeed)as  maxspeed,
	avg(infrastructure) as infrastructure, 
	avg(parallel_rail) as  parallel_rail,
	avg(parallel_bus) as parallel_bus,
	avg(straigthness_score) as straightness,
	avg(time_vs_car) as time_vs_car,
	avg(len_vs_shortest) as len_vs_shortest,
	avg(fahrradfernwege) as fahrradfernwege,
	avg(bicycle_parking) as bicycle_parking,
	avg(bicycle_rental) as bicycle_rental,
	avg(drinking_water) as drinking_water,
	avg(segment_straigthness) as segment_straigthness,
	avg(treecnt) as treecnt,
	avg(park) as park,
	avg(parking) as parking,
	avg(lit) as lit,
	avg(
		(permissions * 1 + 
		 surface * 5 + 
		 maxspeed * 5 + 
		 infrastructure * 10 + 
		 parallel_rail *  4 +
		 parallel_bus * 2 + 
		 straigthness_score * 2 +
		 time_vs_car * 2 +
		 len_vs_shortest * 2 +
		 fahrradfernwege * 2 +
		 bicycle_parking * 2 +
		 bicycle_rental * 2 +
		 drinking_water * 2 +
		 segment_straigthness * 2 +
		 treecnt  * 2 +
		 park * 2 +
		 parking * 5 +
		 lit * 2
		 
		) /54) as final_score
From :v1.routes_extended
);
------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------
