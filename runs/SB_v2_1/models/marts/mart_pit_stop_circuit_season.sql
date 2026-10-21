-- Grain: one row per circuit per season. Pit lane length and speed limit differ by circuit by several seconds, far
-- more than any real improvement, so every season-level comparison must be made WITHIN a circuit.
-- `relative_to_circuit` = this season's median at the circuit / the circuit's median over all seasons
-- (1.00 = typical for that circuit; 0.97 = 3% faster than typical).
with stops as (
    select * from {{ ref('int_pit_stops_routine') }}
),

baseline as (
    select circuit_id, median(duration_seconds) as baseline_seconds, count(distinct season) as seasons_at_circuit
    from stops
    group by 1
)

select
    stops.circuit_id,
    stops.circuit_name,
    stops.season::integer as season,
    count(*)::integer as stops,
    median(stops.duration_seconds)::number(8, 3) as median_seconds,
    baseline.baseline_seconds::number(8, 3) as circuit_baseline_seconds,
    (median(stops.duration_seconds) / baseline.baseline_seconds)::number(8, 4) as relative_to_circuit,
    baseline.seasons_at_circuit::integer as seasons_at_circuit
from stops
inner join baseline on baseline.circuit_id = stops.circuit_id
group by stops.circuit_id, stops.circuit_name, stops.season, baseline.baseline_seconds, baseline.seasons_at_circuit
