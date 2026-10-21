{#
    The answer to "are pit stops getting faster?" as a few numbers with their trend line.

    slope_seconds_per_year is the least-squares slope of adjusted stop time against season, over the stable-circuit stops.
    A negative slope means faster. The 2014 to 2024 period is the current technical regulation era, which is when the
    trend is most relevant, and the 2011 to 2013 period is the older era.
#}
with stops as (

    select * from {{ ref('int_pit_stops_circuit_adjusted') }}
    where circuit_is_stable

),

periods as (

    select 'all seasons' as period, 2011 as first_season, 2024 as last_season
    union all select 'regulation era 2014 to 2024', 2014, 2024
    union all select 'earlier era 2011 to 2013', 2011, 2013

)

select
    periods.period,
    periods.first_season,
    periods.last_season,
    count(stops.race_id) as stable_circuit_stops,
    round(avg(stops.seconds_vs_circuit), 3) as mean_seconds_vs_circuit,
    round(regr_slope(stops.seconds_vs_circuit, stops.season), 4) as slope_seconds_per_year
from periods
inner join stops
    on stops.season between periods.first_season and periods.last_season
group by periods.period, periods.first_season, periods.last_season
