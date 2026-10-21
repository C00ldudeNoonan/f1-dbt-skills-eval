{#
    One row per pit stop (<= 60 s, from 2011), with the stop's time compared with its own circuit's median.
    Pit-lane length and layout differ by circuit, so a raw time mixes circuit effects with crew performance.
    Circuits with fewer than 30 stops in the data have no stable median and are excluded from the adjusted figures.
#}
with stops as (

    select
        pit.race_id,
        pit.driver_id,
        pit.stop_number,
        pit.stop_duration_ms / 1000.0 as stop_seconds,
        races.season,
        races.circuit_id
    from {{ ref('stg_f1__pit_stops') }} as pit
    inner join {{ ref('stg_f1__races') }} as races
        on pit.race_id = races.race_id
    where pit.stop_duration_ms <= 60000

),

circuit_medians as (

    select
        circuit_id,
        median(stop_seconds) as circuit_median_seconds,
        count(*) as circuit_stops
    from stops
    group by circuit_id

)

select
    stops.race_id,
    stops.driver_id,
    stops.stop_number,
    stops.season,
    stops.circuit_id,
    stops.stop_seconds,
    circuit_medians.circuit_median_seconds,
    stops.stop_seconds - circuit_medians.circuit_median_seconds as seconds_vs_circuit,
    circuit_medians.circuit_stops >= 30 as circuit_is_stable
from stops
inner join circuit_medians
    on stops.circuit_id = circuit_medians.circuit_id
