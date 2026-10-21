-- One row per driver per race per teammate (both orderings): the gap in
-- median green-flag lap time (fct_driver_race_pace: excludes lap 1, pit in/out
-- laps and slow laps) between two drivers of the same constructor, when both
-- completed at least var('teammate_race_min_green_laps') green laps.
-- Lap data starts in 1996. gap_pct = 100 * ln(driver / teammate).
with pace as (

    select pace.*, results.constructor_id, results.season
    from {{ ref('fct_driver_race_pace') }} as pace
    inner join (
        select distinct race_id, driver_id, constructor_id, season
        from {{ ref('fct_results') }}
    ) as results
        on pace.race_id = results.race_id
        and pace.driver_id = results.driver_id
    where pace.green_laps >= {{ var('teammate_race_min_green_laps') }}

)

select
    driver.season,
    driver.race_id,
    driver.constructor_id,
    driver.driver_id,
    teammate.driver_id as teammate_id,
    least(driver.green_laps, teammate.green_laps) as shared_green_laps,
    100 * ln(driver.median_green_lap_ms::float / teammate.median_green_lap_ms::float) as gap_pct,
    abs(100 * ln(driver.median_green_lap_ms::float / teammate.median_green_lap_ms::float)) <= {{ var('teammate_gap_max_pct') }}
        as is_representative
from pace as driver
inner join pace as teammate
    on driver.race_id = teammate.race_id
    and driver.constructor_id = teammate.constructor_id
    and driver.driver_id != teammate.driver_id
