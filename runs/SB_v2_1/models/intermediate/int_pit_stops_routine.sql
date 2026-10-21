-- Routine pit stops: durations are PIT LANE time (entry to exit, what the raw feed reports), not the stationary
-- time teams advertise. Stops over 60 s (red flags, repairs) are excluded, as in mart_constructor_season_pit_stops.
select
    pit_stops.race_id,
    races.season,
    races.round,
    races.circuit_id,
    circuits.circuit_name,
    pit_stops.driver_id,
    pit_stops.duration_ms / 1000.0 as duration_seconds
from {{ ref('stg_f1__pit_stops') }} as pit_stops
inner join {{ ref('stg_f1__races') }} as races on races.race_id = pit_stops.race_id
inner join {{ ref('stg_f1__circuits') }} as circuits on circuits.circuit_id = races.circuit_id
where pit_stops.duration_ms <= 60000
