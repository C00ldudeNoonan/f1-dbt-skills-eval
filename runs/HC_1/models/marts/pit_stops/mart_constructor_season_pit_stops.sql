-- Pit stop volume and median stop duration per constructor per season.
-- Stops over 60 seconds are red-flag stoppages, not real pit stops, and are excluded.
with pit_stops as (

    select * from {{ ref('stg_ergast__pit_stops') }}

),

valid_pit_stops as (

    select *
    from pit_stops
    where duration_ms <= 60000

),

race_entries as (

    select distinct
        season,
        race_id,
        driver_id,
        constructor_id
    from {{ ref('fct_results') }}

)

select
    race_entries.season,
    race_entries.constructor_id,
    count(*) as pit_stop_count,
    round(median(valid_pit_stops.duration_ms) / 1000, 3) as median_pit_stop_seconds
from valid_pit_stops
inner join race_entries
    on valid_pit_stops.race_id = race_entries.race_id
    and valid_pit_stops.driver_id = race_entries.driver_id
group by 1, 2
