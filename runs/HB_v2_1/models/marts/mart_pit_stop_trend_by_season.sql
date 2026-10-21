{#
    Pit stop durations by season, 2011 onward. Stops over the red-flag threshold are excluded.

    Durations are total time in the pit lane, not the stationary time in the box. A stop includes
    the pit lane entry and exit, so the pit lane speed limit and the length of each circuit's pit
    lane both change the number.

    circuit_adjusted_* removes circuit mix. Each stop is measured against its own circuit's median
    over all seasons. Only circuits with at least 8 seasons of stops are used. Without this, a
    season with more stops at short pit lanes would look faster for no reason.
#}
{{ config(materialized='table') }}

with stops as (

    select
        races.season,
        races.circuit_id,
        pit_stops.race_id,
        pit_stops.driver_id,
        pit_stops.pit_stop_ms

    from {{ ref('stg_f1__pit_stops') }} as pit_stops
    inner join {{ ref('stg_f1__races') }} as races
        on pit_stops.race_id = races.race_id
    where pit_stops.pit_stop_ms <= {{ var('red_flag_pit_stop_ms') }}

),

circuit_baseline as (

    select
        circuit_id,
        median(pit_stop_ms) as baseline_ms

    from stops
    group by circuit_id
    having count(distinct season) >= 8

),

adjusted as (

    select
        stops.season,
        stops.pit_stop_ms - circuit_baseline.baseline_ms as deviation_ms

    from stops
    inner join circuit_baseline
        on stops.circuit_id = circuit_baseline.circuit_id

)

select
    stops.season,
    count(*) as stops,
    count(distinct stops.race_id) as races,
    median(stops.pit_stop_ms) / 1000 as median_s,
    percentile_cont(0.1) within group (order by stops.pit_stop_ms) / 1000 as p10_s,
    percentile_cont(0.9) within group (order by stops.pit_stop_ms) / 1000 as p90_s,
    (select count(*) from adjusted where adjusted.season = stops.season) as circuit_adjusted_stops,
    (select median(deviation_ms) from adjusted where adjusted.season = stops.season) / 1000
        as circuit_adjusted_median_s,
    (select avg(deviation_ms) from adjusted where adjusted.season = stops.season) / 1000
        as circuit_adjusted_mean_s

from stops
group by stops.season
