-- Each complete season has exactly one champion, and incomplete seasons have none.
-- Returns failing seasons.
with completeness as (

    select * from {{ ref('int_season_completeness') }}

),

champions as (

    select
        season,
        count_if(is_champion) as champion_count
    from {{ ref('mart_driver_season_standings') }}
    group by season

)

select
    completeness.season,
    coalesce(champions.champion_count, 0) as champion_count
from completeness
left join champions
    on completeness.season = champions.season
where completeness.is_season_complete
    and coalesce(champions.champion_count, 0) <> 1

union all

select
    champions.season,
    champions.champion_count
from champions
inner join completeness
    on champions.season = completeness.season
where not completeness.is_season_complete
    and champions.champion_count > 0
