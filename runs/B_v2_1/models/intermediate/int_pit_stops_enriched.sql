{#-
  One row per pit stop with the context needed to compare stops fairly.

  Ergast's pit stop duration is pit-lane time (entry to exit), not the
  stationary time the "1.8-second stop" headlines refer to. Pit-lane time is
  dominated by the pit lane's length and speed limit, which differ hugely by
  circuit. So every stop is compared with its circuit's baseline: the median
  service stop at that circuit over all seasons. delta_vs_circuit_ms < 0
  means faster than usual for that circuit.

  is_service_stop excludes stops over var max_pit_stop_ms (60 s): red-flag
  stoppages, repairs and penalties served in the pit lane.
-#}
with stops as (
    select
        pit_stops.race_id,
        races.season,
        races.round,
        races.circuit_id,
        pit_stops.driver_id,
        entries.constructor_id,
        pit_stops.stop_number,
        pit_stops.lap,
        pit_stops.duration_ms,
        pit_stops.duration_ms <= {{ var('max_pit_stop_ms') }} as is_service_stop
    from {{ ref('stg_ergast__pit_stops') }} as pit_stops
    inner join {{ ref('stg_ergast__races') }} as races
        on pit_stops.race_id = races.race_id
    left join {{ ref('int_race_driver_constructors') }} as entries
        on pit_stops.race_id = entries.race_id
        and pit_stops.driver_id = entries.driver_id
),

circuit_baseline as (
    select
        circuit_id,
        median(duration_ms)         as circuit_median_ms,
        count(distinct season)      as circuit_seasons
    from stops
    where is_service_stop
    group by circuit_id
)

select
    stops.*,
    circuit_baseline.circuit_median_ms,
    circuit_baseline.circuit_seasons,
    iff(stops.is_service_stop, stops.duration_ms - circuit_baseline.circuit_median_ms, null) as delta_vs_circuit_ms
from stops
left join circuit_baseline
    on stops.circuit_id = circuit_baseline.circuit_id
