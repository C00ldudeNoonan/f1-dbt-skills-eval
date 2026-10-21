{#- Are pit stops getting faster? The raw season median is misleading because each season races
    a different mix of circuits and pit lanes differ in length by several seconds. This builds a
    chain-linked index instead (like a price index): for every circuit raced in two consecutive
    seasons, take that circuit's change in median pit lane time, take the median of those changes
    across circuits as the season-on-season change, and chain them from 2011 = 100. A pit lane that
    was rebuilt only distorts the one circuit in the one season it changed, and the median ignores it.
    Higher index = SLOWER. -#}
with circuit_seasons as (

    select * from {{ ref('int_f1__circuit_season_pit_stops') }}

),

yoy as (

    select
        current_season.season,
        current_season.median_seconds / previous_season.median_seconds as ratio
    from circuit_seasons as current_season
    inner join circuit_seasons as previous_season
        on previous_season.circuit_id = current_season.circuit_id
        and previous_season.season = current_season.season - 1

),

changes as (

    select
        season,
        count(*) as circuits_compared,
        median(ratio) as median_ratio
    from yoy
    group by season

),

seasons as (

    select
        races.season,
        count(*) as stops,
        median(stops.duration_ms) / 1000.0 as raw_median_seconds
    from {{ ref('stg_f1__pit_stops') }} as stops
    inner join {{ ref('stg_f1__races') }} as races on races.race_id = stops.race_id
    where stops.duration_ms <= 60000
    group by races.season

)

select
    seasons.season,
    seasons.stops::integer as stops,
    seasons.raw_median_seconds::number(10, 3) as raw_median_seconds,
    changes.circuits_compared::integer as circuits_compared,
    ((changes.median_ratio - 1) * 100)::double as change_vs_previous_season_pct,
    (100 * exp(sum(ln(coalesce(changes.median_ratio, 1))) over (order by seasons.season)))::double as chained_index
from seasons
left join changes on changes.season = seasons.season
