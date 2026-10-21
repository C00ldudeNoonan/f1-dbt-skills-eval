-- "Are pit stops getting faster?" One row per season (2011+).
--
-- raw_median_seconds is what a naive chart would show: it mixes circuits with
-- very different pit lanes. The answer uses circuit_adjusted_delta_seconds:
-- per circuit-season, the median stop minus that circuit's all-season median;
-- then the median over circuits (each circuit weighted equally, so a calendar
-- heavy in slow pit lanes can't fake a trend), with a 95% interval from the
-- spread across circuits. Only circuits used in at least
-- var('pit_trend_min_circuit_seasons') seasons count, so every circuit has a
-- meaningful baseline. Negative = faster than that circuit's norm.
with stops as (

    select * from {{ ref('int_pit_stops__circuit_adjusted') }}

),

circuit_seasons as (

    select
        season,
        circuit_id,
        count(*) as stops,
        median(delta_vs_circuit_ms) as median_delta_ms
    from stops
    where circuit_seasons >= {{ var('pit_trend_min_circuit_seasons') }}
    group by 1, 2

),

adjusted as (

    select
        season,
        count(*) as circuits_compared,
        median(median_delta_ms) as median_delta_ms,
        stddev(median_delta_ms) / sqrt(count(*)) as se_delta_ms
    from circuit_seasons
    group by 1

),

raw as (

    select
        season,
        count(*) as pit_stops,
        count(distinct circuit_id) as circuits,
        median(duration_ms) as raw_median_ms,
        percentile_cont(0.1) within group (order by delta_vs_circuit_ms) as p10_delta_ms,
        min(duration_ms) as fastest_ms
    from stops
    group by 1

)

select
    raw.season,
    raw.pit_stops,
    raw.circuits,
    round(raw.raw_median_ms / 1000, 2) as raw_median_seconds,
    adjusted.circuits_compared,
    round(adjusted.median_delta_ms / 1000, 2) as circuit_adjusted_delta_seconds,
    round((adjusted.median_delta_ms - 1.96 * adjusted.se_delta_ms) / 1000, 2) as circuit_adjusted_ci_low,
    round((adjusted.median_delta_ms + 1.96 * adjusted.se_delta_ms) / 1000, 2) as circuit_adjusted_ci_high,
    round(raw.p10_delta_ms / 1000, 2) as fastest_decile_delta_seconds,
    round(raw.fastest_ms / 1000, 2) as fastest_stop_seconds
from raw
inner join adjusted
    on raw.season = adjusted.season
