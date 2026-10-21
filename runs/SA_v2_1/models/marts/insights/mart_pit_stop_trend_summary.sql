-- Single row answering "is there a trend?": regression of the circuit-relative stop time on season over all
-- like-for-like stops, plus a circuit-by-circuit sign count. slope_pct_per_year is the change in a typical
-- stop's pit lane time per year as a percentage of that circuit's baseline (negative = faster). The t statistic
-- treats stops as independent, which flatters it (stops in one race share conditions), so read |t| < 3 as
-- "no evidence of a trend". Also reports the 2011-13 vs 2022-24 comparison on the same circuits.
with stops as (

    select * from {{ ref('int_pit_stops_enriched') }} where is_included

),

circuit_baseline as (

    select circuit_id, median(duration_s) as baseline_s
    from stops
    group by circuit_id
    having count(distinct season) >= 6

),

indexed as (

    select
        stops.season,
        stops.circuit_id,
        stops.duration_s,
        100.0 * stops.duration_s / circuit_baseline.baseline_s - 100 as pct_vs_circuit_baseline
    from stops
    inner join circuit_baseline on stops.circuit_id = circuit_baseline.circuit_id

),

regression as (

    select
        count(*) as stops,
        regr_slope(pct_vs_circuit_baseline, season) as slope_pct_per_year,
        regr_r2(pct_vs_circuit_baseline, season) as r2,
        sign(regr_slope(pct_vs_circuit_baseline, season)) * sqrt(regr_r2(pct_vs_circuit_baseline, season)) as r,
        count_if(season >= 2014) as stops_2014_on,
        regr_slope(case when season >= 2014 then pct_vs_circuit_baseline end, case when season >= 2014 then season end) as slope_2014_on,
        regr_r2(case when season >= 2014 then pct_vs_circuit_baseline end, case when season >= 2014 then season end) as r2_2014_on
    from indexed

),

circuit_season as (

    select circuit_id, season, median(pct_vs_circuit_baseline) as m
    from indexed
    group by circuit_id, season

),

circuit_slopes as (

    select circuit_id, regr_slope(m, season) as slope, count(*) as n_seasons
    from circuit_season
    group by circuit_id
    having count(*) >= 6

),

early_vs_late as (

    select
        circuit_id,
        median(case when season between 2011 and 2013 then m end) as early,
        median(case when season between 2022 and 2024 then m end) as late
    from circuit_season
    group by circuit_id

)

select
    regression.stops,
    (select count(*) from circuit_slopes) as circuits_compared,
    regression.slope_pct_per_year,
    regression.r * sqrt((regression.stops - 2) / (1 - regression.r2)) as t_statistic,
    regression.slope_2014_on as slope_pct_per_year_2014_on,
    sign(regression.slope_2014_on) * sqrt(regression.r2_2014_on)
        * sqrt((regression.stops_2014_on - 2) / (1 - regression.r2_2014_on)) as t_statistic_2014_on,
    (select count_if(slope < 0) from circuit_slopes) as circuits_getting_faster,
    (select count_if(slope > 0) from circuit_slopes) as circuits_getting_slower,
    (select median(late - early) from early_vs_late where early is not null and late is not null) as median_change_2011_13_to_2022_24_pct,
    (select count(*) from early_vs_late where early is not null and late is not null) as circuits_in_early_late_comparison,
    (select count_if(late < early) from early_vs_late where early is not null and late is not null) as circuits_faster_late
from regression
