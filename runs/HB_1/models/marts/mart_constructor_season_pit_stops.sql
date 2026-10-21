-- One row per constructor per season with pit stop data.
-- Red-flag stoppages (longer than 60 seconds) are excluded.
-- Constructor is taken from the driver's result entry for that race.
with pit_stops as (

    select * from {{ ref('stg_f1__pit_stops') }}
    where duration_ms <= 60000

),

results as (

    select * from {{ ref('fct_results') }}

)

select
    results.season,
    results.constructor_id,
    results.constructor_name,
    count(*) as pit_stop_count,
    round(median(pit_stops.duration_ms) / 1000.0, 3) as median_pit_stop_seconds
from pit_stops
inner join results
    on results.race_id = pit_stops.race_id
    and results.driver_id = pit_stops.driver_id
group by
    results.season,
    results.constructor_id,
    results.constructor_name
