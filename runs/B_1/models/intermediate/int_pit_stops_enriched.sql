{#
    Pit stops with season and the constructor the driver raced for in that
    Grand Prix. Pit stop data only exists from 2011, after shared drives ended,
    so (race_id, driver_id) maps to exactly one result row.
#}

with pit_stops as (
    select * from {{ ref('stg_ergast__pit_stops') }}
),

results as (
    select * from {{ ref('stg_ergast__results') }}
),

races as (
    select * from {{ ref('stg_ergast__races') }}
)

select
    pit_stops.race_id,
    pit_stops.driver_id,
    pit_stops.stop_number,
    races.season,
    results.constructor_id,
    pit_stops.lap,
    pit_stops.duration_ms,
    pit_stops.duration_seconds,
    -- Stops over a minute are red-flag stoppages, not genuine pit stops.
    pit_stops.duration_seconds > {{ var('max_pit_stop_seconds') }} as is_red_flag_stoppage
from pit_stops
inner join races
    on pit_stops.race_id = races.race_id
inner join results
    on pit_stops.race_id = results.race_id
    and pit_stops.driver_id = results.driver_id
