-- Answers "are pit stops getting faster?" as well as the data allows. One row
-- per season with pit stop data. The headline is the circuit-adjusted
-- figure: each race compared with the same circuit's norm, so changes in the
-- calendar (different circuits, different pit-lane lengths) don't masquerade
-- as a trend. Only races in the current speed-limit regime (from mid-2013,
-- see mart_race_pit_lane_times) at circuits with at least 3 such races
-- count towards it. The raw median is shown for contrast.
--
-- trend_seconds_per_season is the least-squares slope of the race-level
-- circuit-adjusted median over seasons, for the current regime. It is the
-- same value on every row.

with races as (
    select * from {{ ref('mart_race_pit_lane_times') }}
),

comparable as (
    select *
    from races
    where is_current_regime
        and baseline_races >= 3
),

stops as (
    select
        races.season,
        pit_stops.duration_ms / 1000.0 as seconds
    from {{ ref('stg_f1__pit_stops') }} as pit_stops
    inner join races
        on pit_stops.race_id = races.race_id
    where pit_stops.duration_ms <= 60000
),

raw_by_season as (
    select
        season,
        count(*) as stops,
        median(seconds) as raw_median_seconds
    from stops
    group by season
),

adjusted_by_season as (
    select
        season,
        count(*) as comparable_races,
        count(distinct circuit_id) as comparable_circuits,
        median(median_vs_circuit_seconds) as adjusted_median_vs_circuit_seconds,
        median(p10_vs_circuit_seconds) as adjusted_p10_vs_circuit_seconds
    from comparable
    group by season
),

trend as (
    select
        regr_slope(median_vs_circuit_seconds, season) as trend_seconds_per_season,
        regr_slope(p10_vs_circuit_seconds, season) as p10_trend_seconds_per_season,
        regr_r2(median_vs_circuit_seconds, season) as trend_r2,
        count(*) as trend_races
    from comparable
)

select
    raw_by_season.season,
    raw_by_season.stops,
    raw_by_season.raw_median_seconds::number(8, 3) as raw_median_seconds,
    coalesce(adjusted_by_season.comparable_races, 0) as comparable_races,
    coalesce(adjusted_by_season.comparable_circuits, 0) as comparable_circuits,
    adjusted_by_season.adjusted_median_vs_circuit_seconds::number(8, 3) as adjusted_median_vs_circuit_seconds,
    adjusted_by_season.adjusted_p10_vs_circuit_seconds::number(8, 3) as adjusted_p10_vs_circuit_seconds,
    trend.trend_seconds_per_season::number(8, 4) as trend_seconds_per_season,
    trend.p10_trend_seconds_per_season::number(8, 4) as p10_trend_seconds_per_season,
    trend.trend_r2::number(8, 4) as trend_r2,
    trend.trend_races
from raw_by_season
left join adjusted_by_season
    on raw_by_season.season = adjusted_by_season.season
cross join trend
