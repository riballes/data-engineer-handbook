/*
    This week's assignment involves working with the actor_films dataset. 
    Your task is to construct a series of SQL queries and table definitions 
    that will allow us to model the actor_films dataset in a way that 
    facilitates efficient analysis. This involves creating new tables, 
    defining data types, and writing queries to populate these tables with 
    data from the actor_films dataset.
*/

-- 1) DDL for actors table

-- Drop TABLE and TYPES
DROP TABLE actors
-- DROP TYPE films
-- DROP TYPE quality_class


-- 1.1) Create films Structure
CREATE TYPE films AS (
    film TEXT,
    year INTEGER,
    votes INTEGER,
    rating REAL,
    filmid TEXT
);

-- 1.2) Create a quality_class Structure
CREATE TYPE quality_class AS
    ENUM (
        'star',
        'good',
        'average',
        'bad'
    );

-- 1.3) Table Creation
CREATE TABLE actors (
    actor_name TEXT,
    actorid TEXT,
    current_year INTEGER,
    films films[],
    quality_class quality_class,
    is_active BOOLEAN,
    PRIMARY KEY(actor_name, actorid, current_year)
);

-- 2) Generate cumulative table
INSERT INTO actors
WITH yesterday AS (
    SELECT *
    FROM actors
    WHERE current_year = 1972
),
today AS(
    SELECT
        actor,
        actorid,
        year,
        ARRAY_AGG(
            ROW(film,
                year,
                votes,
                rating,
                filmid
            )::films
        ) AS films,
        AVG(rating) AS rating 
    FROM actor_films
    WHERE year = 1973
    GROUP BY
        actor,
        actorid,
        year
)
SELECT
    COALESCE(t.actor,y.actor_name) AS actor_name,
    COALESCE(t.actorid,y.actorid) AS actorid,
    COALESCE(t.year,y.current_year + 1) AS current_year,
    CASE
        WHEN y.films IS NULL THEN t.films
        WHEN t.films IS NOT NULL THEN y.films || t.films
        ELSE y.films
    END AS films,
    CASE
        WHEN t.rating IS NOT NULL THEN
            CASE
                WHEN t.rating > 8 THEN 'star'
                WHEN t.rating > 7 THEN 'good'
                WHEN t.rating > 6 THEN 'average'
                ELSE 'bad'
            END::quality_class
        ELSE y.quality_class
    END quality_class,
    CASE
        WHEN t.year IS NOT NULL THEN TRUE
        ELSE FALSE
    END is_active
FROM today t
FULL OUTER JOIN yesterday y
ON t.actor = y.actor_name
    AND t.actorid = y.actorid


-- Check Table
SELECT *
FROM actors
WHERE current_year = 1973











