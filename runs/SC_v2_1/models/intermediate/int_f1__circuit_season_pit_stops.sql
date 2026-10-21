-- Pit lane time per circuit per season. Time is the whole pit lane transit (entry to exit, as
-- recorded in `milliseconds`), NOT the stationary time. Stops over 60 s are red-flag stoppages and
-- excluded, the same rule as mart_constructor_season_pit_stops. A circuit-season needs a minimum of
-- min_stops stops to be used for comparisons.
{% set max_stop_ms = 60000 %}
{% set min_stops = 8 %}

select
    races.circuit_id,
    races.season,
    count(*)::integer as stops,
    median(stops.duration_ms) / 1000.0 as median_seconds
from {{ ref('stg_f1__pit_stops') }} as stops
inner join {{ ref('stg_f1__races') }} as races on races.race_id = stops.race_id
where stops.duration_ms <= {{ max_stop_ms }}
group by races.circuit_id, races.season
having count(*) >= {{ min_stops }}
