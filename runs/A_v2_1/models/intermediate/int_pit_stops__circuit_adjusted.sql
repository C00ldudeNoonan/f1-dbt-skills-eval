-- One row per pit stop (2011+, red-flag stoppages over
-- var('pit_stop_max_seconds') excluded) with its pit-lane time compared with
-- the same circuit's median across all seasons.
--
-- The feed's duration is PIT-LANE time (entry to exit, ~20-30 s), not the
-- stationary tyre-change time (~2-3 s). Pit lanes differ by length and speed
-- limit, so raw times mostly reflect which circuits were on the calendar;
-- comparing each stop with its own circuit removes that.
with stops as (

    select
        pit_stops.race_id,
        pit_stops.driver_id,
        pit_stops.stop_number,
        pit_stops.lap,
        pit_stops.duration_ms,
        races.season,
        races.circuit_id
    from {{ ref('stg_ergast__pit_stops') }} as pit_stops
    inner join {{ ref('stg_ergast__races') }} as races
        on pit_stops.race_id = races.race_id
    where pit_stops.duration_ms <= {{ var('pit_stop_max_seconds') }} * 1000

),

circuit_baseline as (

    select
        circuit_id,
        median(duration_ms) as circuit_median_ms,
        count(distinct season) as circuit_seasons
    from stops
    group by 1

)

select
    stops.*,
    circuit_baseline.circuit_median_ms,
    circuit_baseline.circuit_seasons,
    stops.duration_ms - circuit_baseline.circuit_median_ms as delta_vs_circuit_ms
from stops
inner join circuit_baseline
    on stops.circuit_id = circuit_baseline.circuit_id
