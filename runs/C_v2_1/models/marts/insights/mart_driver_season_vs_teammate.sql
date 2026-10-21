-- One row per driver, season and constructor: how the driver compared with
-- their teammate(s) in the same car. Qualifying pace comes from
-- int_f1__teammate_qualifying_comparisons (outliers excluded). Race
-- head-to-head counts only Grands Prix where both cars were classified, so
-- mechanical retirements don't count against a driver.

with comparisons as (
    select * from {{ ref('int_f1__teammate_qualifying_comparisons') }}
),

results as (
    select * from {{ ref('fct_results') }}
),

qualifying as (
    select
        driver_id,
        season,
        constructor_id,
        count(*) as qualifying_comparisons,
        count_if(not is_outlier) as clean_qualifying_comparisons,
        median(case when not is_outlier then pace_advantage_pct end) as median_pace_advantage_pct,
        count_if(pace_advantage_pct > 0) as qualifying_wins,
        listagg(distinct teammate_id, ',') within group (order by teammate_id) as teammate_ids
    from comparisons
    group by driver_id, season, constructor_id
),

classified as (
    select race_id, constructor_id, driver_id, season, min(finish_position) as finish_position
    from results
    where finish_position is not null
        and season >= {{ var('teammate_pace_first_season', 2006) }}
    group by race_id, constructor_id, driver_id, season
),

race_head_to_head as (
    select
        driver.driver_id,
        driver.season,
        driver.constructor_id,
        count(*) as race_comparisons,
        count_if(driver.finish_position < teammate.finish_position) as race_wins
    from classified as driver
    inner join classified as teammate
        on driver.race_id = teammate.race_id
        and driver.constructor_id = teammate.constructor_id
        and driver.driver_id <> teammate.driver_id
    group by driver.driver_id, driver.season, driver.constructor_id
)

select
    qualifying.driver_id,
    qualifying.season,
    qualifying.constructor_id,
    qualifying.teammate_ids,
    qualifying.qualifying_comparisons,
    qualifying.clean_qualifying_comparisons,
    qualifying.median_pace_advantage_pct::float as median_pace_advantage_pct,
    qualifying.qualifying_wins,
    coalesce(race_head_to_head.race_comparisons, 0) as race_comparisons,
    coalesce(race_head_to_head.race_wins, 0) as race_wins
from qualifying
left join race_head_to_head
    on qualifying.driver_id = race_head_to_head.driver_id
    and qualifying.season = race_head_to_head.season
    and qualifying.constructor_id = race_head_to_head.constructor_id
