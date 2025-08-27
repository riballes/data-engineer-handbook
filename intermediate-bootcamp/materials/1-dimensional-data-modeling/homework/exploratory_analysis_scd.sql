/*
    Digging into Slowly Changing Dimensions (SCD)
*/

-- -- Cleaning up before starting from previous work.
-- DROP TABLE players;

-- -- Reusing previous custom types

-- CREATE TYPE season_stats AS(
--     season INTEGER,
--     gp INTEGER,
--     pts REAL,
--     reb REAL,
--     ast REAL

-- );

-- CREATE TYPE scoring_class AS
--     ENUM(
--         'star',
--         'good',
--         'average',
--         'bad'
--     );

-- -- 1) Creating a new players Table
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
--     is_active BOOLEAN,
--     PRIMARY KEY(player_name,current_season)
-- )


-- -- Figuring out time boundaries of our data
-- SELECT MIN(season), MAX(season) FROM player_seasons

-- -- Seed Query
-- INSERT INTO players
-- WITH years AS (
--     SELECT *
--     FROM generate_series(1996,2022) AS season
-- ),
-- player AS (
--     SELECT
--         player_name,
--         MIN(season) AS first_season
--     FROM player_seasons
--     GROUP BY
--         player_name
-- ),
-- players_and_seasons AS (
--     SELECT *
--     FROM player p
--     JOIN years y 
--         ON p.first_season <= y.season
-- ),
-- windowed AS (
--     SELECT
--         pas.player_name,
--         pas.season,
--         ARRAY_REMOVE(
--             ARRAY_AGG(
--                 CASE
--                     WHEN ps.season IS NOT NULL THEN ROW(
--                         ps.season,
--                         ps.gp,
--                         ps.pts,
--                         ps.reb,
--                         ps.ast
--                     )::season_stats
--                 END

--         ) OVER (PARTITION BY pas.player_name ORDER BY COALESCE(pas.season,ps.season)),
--         NULL) AS seasons
--     FROM players_and_seasons pas
--     LEFT JOIN player_seasons ps
--         ON pas.player_name = ps.player_name
--         AND pas.season = ps.season
--     ORDER BY pas.player_name, pas.season
-- ),
-- static_info AS (
--     SELECT
--         player_name,
--         MAX(height) AS height,
--         MAX(college) AS college,
--         MAX(country) AS country,
--         MAX(draft_year) AS draft_year,
--         MAX(draft_round) AS draft_round,
--         MAX(draft_number) AS draft_number
--     FROM player_seasons
--     GROUP BY player_name
-- )
-- SELECT
--     w.player_name,
--     s.height,
--     s.college,
--     s.country,
--     s.draft_year,
--     s.draft_round,
--     s.draft_number,
--     seasons AS season_stats,
--     CASE
--         WHEN (seasons[CARDINALITY(seasons)]::season_stats).pts > 20 THEN 'star'
--         WHEN (seasons[CARDINALITY(seasons)]::season_stats).pts > 15 THEN 'good'
--         WHEN (seasons[CARDINALITY(seasons)]::season_stats).pts > 10 THEN 'average'
--         ELSE 'bad'
--     END::scoring_class AS scoring_class,
--     w.season - (seasons[CARDINALITY(seasons)]::season_stats).season as years_since_last_active,
--     w.season AS current_season,
--     (seasons[CARDINALITY(seasons)]::season_stats).season = season AS is_active
-- FROM windowed w
-- JOIN static_info s
--     ON w.player_name = s.player_name;

-- -- Checking Data
-- SELECT *
-- FROM players
-- WHERE current_season = 2022

/*
    Starting with SCD
*/

-- 2) Focus on SCD table
-- Tracking scoring_class and is_active
-- DROP TABLE players_scd
CREATE TABLE players_scd (
    player_name TEXT,
    scoring_class scoring_class,
    is_active BOOLEAN,
    start_season INTEGER,
    end_season INTEGER,
    current_season INTEGER,
    PRIMARY KEY(player_name, start_season, end_season)
);

-- 3) Developing the SCD table
INSERT INTO players_scd
WITH with_previous AS (
    SELECT
        player_name,
        current_season,
        scoring_class,
        is_active,
        LAG(scoring_class,1) OVER (PARTITION BY player_name ORDER BY current_season) AS prev_scoring_class,
        LAG(is_active,1) OVER (PARTITION BY player_name ORDER BY current_season) AS prev_is_active
    FROM players
),
with_indicators AS (
    SELECT *,
        CASE
            WHEN scoring_class <> prev_scoring_class THEN 1
            WHEN is_active <> prev_is_active THEN 1
            ELSE 0
        END chg_indicator
    FROM with_previous
),
with_streaks AS (
    SELECT *,
        SUM(chg_indicator) OVER (PARTITION BY player_name ORDER BY current_season) AS streak_indentifier
    FROM with_indicators
)
SELECT 
    player_name,
    scoring_class,
    is_active,
    MIN(current_season) AS start_season,
    MAX(current_season) AS end_season,
    2021 AS current_season
FROM with_streaks
GROUP BY
    player_name,
    streak_indentifier,
    is_active,
    scoring_class
ORDER BY
    player_name,
    streak_indentifier


-- Checking Data
SELECT *
FROM players_scd