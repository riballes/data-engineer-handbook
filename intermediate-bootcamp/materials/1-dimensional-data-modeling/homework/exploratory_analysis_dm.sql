/*
    Looking at Dimensional Data Modeling Lecture
    Starting analysis with players_seasons
    Every row in the table is a player and their season
*/

-- SELECT *
-- FROM player_seasons;

-- 1) Identify static attributes and dynamic attributes (changing)
-- 2) Create a struct that can represent what we care about the season of each player

-- CREATE TYPE season_stats AS(
--     season INTEGER,
--     gp INTEGER,
--     pts REAL,
--     reb REAL,
--     ast REAL

-- );

-- 7) Create scoring class
-- CREATE TYPE scoring_class AS
--     ENUM(
--         'star',
--         'good',
--         'average',
--         'bad'
--     )

-- 3) Array of season_stats + add scoring_class

-- CREATE TABLE players (
--     player_name TEXT,
--     height TEXT,
--     college TEXT,
--     country TEXT,
--     draft_year TEXT,
--     draft_round TEXT,
--     draft_number TEXT,
--     season_stats season_stats[],
--     scoring_class scoring_class,
--     years_since_last_season INTEGER,
--     current_season INTEGER,
--     PRIMARY KEY(player_name, current_season)
-- );

/*
    The table is developed cumulatively, so having a notion of the latest season
    or current_season is fundamental along with the season_stats
*/

-- 4) Define your comparison structure (today vs yesterday)
-- Seed Query
INSERT INTO players
WITH yesterday AS (
    SELECT *
    FROM players
    WHERE current_season = 2000
),
today AS (
    SELECT *
    FROM player_seasons
    WHERE season = 2001
)
SELECT
    COALESCE(t.player_name,y.player_name) AS player_name,
    COALESCE(t.height,y.height) AS height,
    COALESCE(t.college,y.college) AS college,
    COALESCE(t.country,y.country) AS country,
    COALESCE(t.draft_year,y.draft_year) AS draft_year,
    COALESCE(t.draft_round,y.draft_round) AS draft_round,
    COALESCE(t.draft_number,y.draft_number) AS draft_number,
    CASE
        WHEN y.season_stats IS NULL THEN
            ARRAY[ROW(
                t.season,
                t.gp,
                t.pts,
                t.reb,
                t.ast
            )::season_stats]
        WHEN t.season IS NOT NULL THEN 
            y.season_stats || ARRAY[ROW(
                t.season,
                t.gp,
                t.pts,
                t.reb,
                t.ast
            )::season_stats]
        ELSE y.season_stats
    END AS season_stats,
    CASE
        WHEN t.season IS NOT NULL THEN
            CASE
                WHEN t.pts > 20 THEN 'star'
                WHEN t.pts > 15 THEN 'good'
                WHEN t.pts > 10 THEN 'average'
                ELSE 'bad'
            END::scoring_class
        ELSE y.scoring_class
    END AS scoring_class,
    CASE
        WHEN t.season IS NOT NULL THEN 0
        ELSE y.years_since_last_season + 1
    END AS years_since_last_season,
    COALESCE(t.season, y.current_season + 1) AS current_season
FROM today t
FULL OUTER JOIN yesterday y
ON t.player_name = y.player_name;


-- Testing Table
-- EXPLAIN ANALYZE
SELECT *
FROM players
WHERE current_season = 2001
ORDER BY player_name


-- 5) Returning the Table to its original form (Unnest)
WITH unnested AS (
    SELECT 
        player_name,
        UNNEST(season_stats)::season_stats AS season_stats
    FROM players
    WHERE current_season = 2001
    -- AND player_name = 'Michael Jordan'
)
SELECT 
    player_name,
    (season_stats::season_stats).*
FROM unnested;


-- 6) Drop table
-- DROP TABLE players;




