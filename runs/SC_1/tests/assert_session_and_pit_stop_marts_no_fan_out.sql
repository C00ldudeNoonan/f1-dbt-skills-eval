-- Pit stop counts per season can never exceed raw pit stops of that season (<= 60s).
with raw_by_season as (

    select races.season, count(*) as stops
    from {{ ref('stg_f1__pit_stops') }} as pit_stops
    inner join {{ ref('stg_f1__races') }} as races on pit_stops.race_id = races.race_id
    where pit_stops.duration_ms <= 60000
    group by races.season

),

mart_by_season as (

    select season, sum(pit_stop_count) as stops
    from {{ ref('mart_constructor_season_pit_stops') }}
    group by season

)

select raw_by_season.season
from raw_by_season
full outer join mart_by_season using (season)
where raw_by_season.stops is distinct from mart_by_season.stops
