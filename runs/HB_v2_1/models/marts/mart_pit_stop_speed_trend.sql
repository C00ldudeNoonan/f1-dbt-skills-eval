{#
    One row: is the pit stop getting faster? The trend uses circuit-adjusted stop durations from
    mart_pit_stop_trend_by_season's basis (the deviation from each circuit's median), regressed on
    season.

    slope_ms_per_season is the change in the average circuit-adjusted stop per season. Negative
    means faster. r_squared says how much of the stop-to-stop variation the season explains,
    which is usually small. The median series is reported as well, because the mean is pulled by
    slow outliers.
#}
{{ config(materialized='table') }}

with stops as (

    select
        races.season,
        races.circuit_id,
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

),

season_medians as (

    select
        season,
        median(deviation_ms) as adjusted_median_ms

    from adjusted
    group by season

)

select
    count(*) as stops_used,
    count(distinct season) as seasons,
    min(season) as first_season,
    max(season) as last_season,
    regr_slope(deviation_ms, season) as slope_ms_per_season,
    regr_r2(deviation_ms, season) as r_squared,
    (select regr_slope(adjusted_median_ms, season) from season_medians) as median_slope_ms_per_season,
    (select avg(adjusted_median_ms) from season_medians where season between 2011 and 2013) / 1000
        as adjusted_median_2011_2013_s,
    (select avg(adjusted_median_ms) from season_medians where season between 2022 and 2024) / 1000
        as adjusted_median_2022_2024_s

from adjusted
