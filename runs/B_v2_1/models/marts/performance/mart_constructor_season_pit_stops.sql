{#-
  Pit stop counts and median stop time per constructor per season.
  Stops longer than max_pit_stop_ms (60s) are red-flag stoppages and are excluded.
  A driver's constructor for a race comes from their Grand Prix result.
-#}
with pit_stops as (
    select * from {{ ref('stg_ergast__pit_stops') }}
    where duration_ms <= {{ var('max_pit_stop_ms') }}
),

entries as (
    select * from {{ ref('int_race_driver_constructors') }}
),

races as (
    select * from {{ ref('stg_ergast__races') }}
)

select
    races.season,
    entries.constructor_id,
    count(*)                                    as pit_stop_count,
    round(median(pit_stops.duration_ms) / 1000, 3)::number(10, 3) as median_pit_stop_seconds
from pit_stops
inner join entries
    on pit_stops.race_id = entries.race_id
    and pit_stops.driver_id = entries.driver_id
inner join races
    on pit_stops.race_id = races.race_id
group by races.season, entries.constructor_id
