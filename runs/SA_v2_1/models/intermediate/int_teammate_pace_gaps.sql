-- Race-pace counterpart of int_teammate_qualifying_gaps: median green-flag lap of the driver relative to
-- the teammate's in the same race and constructor (percent, negative = faster). Needs at least 10 green
-- laps each; gaps beyond +/-5% are dropped (damage, wet/dry tyre splits, long stints in traffic).
with entries as (

    select
        pace.race_id,
        results.season,
        results.constructor_id,
        pace.driver_id,
        pace.median_green_lap_ms
    from {{ ref('fct_driver_race_pace') }} as pace
    inner join (
        select distinct race_id, season, driver_id, constructor_id from {{ ref('fct_results') }}
    ) as results
        on pace.race_id = results.race_id and pace.driver_id = results.driver_id
    where pace.green_laps >= 10

)

select
    a.season,
    a.race_id,
    a.constructor_id,
    a.driver_id,
    b.driver_id as teammate_id,
    100.0 * (a.median_green_lap_ms - b.median_green_lap_ms) / b.median_green_lap_ms as gap_pct
from entries as a
inner join entries as b
    on a.race_id = b.race_id
    and a.constructor_id = b.constructor_id
    and a.driver_id <> b.driver_id
where abs(100.0 * (a.median_green_lap_ms - b.median_green_lap_ms) / b.median_green_lap_ms) <= 5
