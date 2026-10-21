{#
  Pit stops enriched with season and the constructor the driver raced for in
  that Grand Prix. Pit stop data has no constructor column, so it is attributed
  through the driver's result row for the same race. (Shared drives — the only
  case where a driver has two result rows in one race — ended decades before
  pit stop data begins in 2011; the grain test on this model guards that.)
#}

with pit_stops as (
    select * from {{ ref('stg_ergast__pit_stops') }}
),

results as (
    select race_id, driver_id, constructor_id from {{ ref('stg_ergast__results') }}
),

races as (
    select race_id, season, round from {{ ref('stg_ergast__races') }}
)

select
    pit_stops.race_id,
    pit_stops.driver_id,
    pit_stops.stop_number,
    races.season,
    races.round,
    results.constructor_id,
    pit_stops.lap,
    pit_stops.duration_ms,
    pit_stops.duration_seconds,
    -- Stops over 60s are red-flag stoppages / repairs, not real pit stops.
    pit_stops.duration_ms <= 60000 as is_representative_stop
from pit_stops
inner join races
    on pit_stops.race_id = races.race_id
left join results
    on pit_stops.race_id = results.race_id
   and pit_stops.driver_id = results.driver_id
