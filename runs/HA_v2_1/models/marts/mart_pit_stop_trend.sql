{#
    One row per season: pit stop duration distribution across all teams. Stops longer than
    max_pit_stop_duration_ms (red flags) are excluded, as in mart_constructor_season_pit_stops.
    Medians and quartiles are used because a few slow stops would move an average. stops_per_race
    shows whether the number of stops changed, since that changes what a "typical" stop is.
#}
with stops as (

    select
        races.season,
        races.race_id,
        pit_stops.duration_ms
    from {{ ref('stg_f1__pit_stops') }} as pit_stops
    inner join {{ ref('stg_f1__races') }} as races
        on pit_stops.race_id = races.race_id
    where pit_stops.duration_ms <= {{ var('max_pit_stop_duration_ms') }}

)

select
    season,
    count(*) as stops,
    count(distinct race_id) as races_with_stops,
    count(*) / count(distinct race_id) as stops_per_race,
    median(duration_ms) / 1000.0 as median_seconds,
    percentile_cont(0.25) within group (order by duration_ms) / 1000.0 as p25_seconds,
    percentile_cont(0.75) within group (order by duration_ms) / 1000.0 as p75_seconds
from stops
group by season
