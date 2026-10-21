-- One row per race, constructor, driver and teammate (both orderings) where
-- the two cars can be compared on pace. Teammates share a car, so the gap
-- between them is the cleanest available measure of driver performance
-- independent of the car.
--
-- Rules:
--   * Seasons from 2006 (var `teammate_pace_first_season`). 2003-2005 used
--     one-lap, race-fuel qualifying, and earlier seasons have sparse times.
--   * Only constructors with exactly two qualifying entries in the race
--     (excludes third cars and mid-weekend substitutions).
--   * Compare the last session both drivers set a time in (Q3, else Q2,
--     else Q1), so track evolution and fuel are comparable. Before 2010 Q3
--     was run on race fuel, so for those seasons Q3 is skipped.
--   * pace_advantage_pct is positive when the driver was faster:
--     (teammate time - driver time) / teammate time * 100.
--   * Gaps over 2% are flagged as outliers (crashes, mechanical problems,
--     changing weather) and left out of the summary medians.

{% set first_season = var('teammate_pace_first_season', 2006) %}

with entries as (
    select *
    from {{ ref('int_f1__qualifying_entries') }}
    where season >= {{ first_season }}
),

two_car_teams as (
    select race_id, constructor_id
    from entries
    group by race_id, constructor_id
    having count(*) = 2
),

pairs as (
    select
        driver.race_id,
        driver.season,
        driver.round,
        driver.constructor_id,
        driver.driver_id,
        teammate.driver_id as teammate_id,
        driver.qualifying_position as driver_qualifying_position,
        teammate.qualifying_position as teammate_qualifying_position,
        case
            when driver.season >= 2010 and driver.q3_ms is not null and teammate.q3_ms is not null then 'Q3'
            when driver.q2_ms is not null and teammate.q2_ms is not null then 'Q2'
            when driver.q1_ms is not null and teammate.q1_ms is not null then 'Q1'
        end as compared_session,
        case compared_session
            when 'Q3' then driver.q3_ms
            when 'Q2' then driver.q2_ms
            when 'Q1' then driver.q1_ms
        end as driver_time_ms,
        case compared_session
            when 'Q3' then teammate.q3_ms
            when 'Q2' then teammate.q2_ms
            when 'Q1' then teammate.q1_ms
        end as teammate_time_ms
    from entries as driver
    inner join entries as teammate
        on driver.race_id = teammate.race_id
        and driver.constructor_id = teammate.constructor_id
        and driver.driver_id <> teammate.driver_id
    inner join two_car_teams
        on driver.race_id = two_car_teams.race_id
        and driver.constructor_id = two_car_teams.constructor_id
)

select
    race_id,
    season,
    round,
    constructor_id,
    driver_id,
    teammate_id,
    compared_session,
    driver_time_ms,
    teammate_time_ms,
    ((teammate_time_ms - driver_time_ms) * 100.0 / teammate_time_ms)::float as pace_advantage_pct,
    abs((teammate_time_ms - driver_time_ms) * 100.0 / teammate_time_ms) > 2 as is_outlier,
    driver_qualifying_position,
    teammate_qualifying_position
from pairs
where compared_session is not null
