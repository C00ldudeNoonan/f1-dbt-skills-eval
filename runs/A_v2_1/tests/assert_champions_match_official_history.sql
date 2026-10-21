-- Every completed season's championship leader (and their points) must match the
-- hand-maintained list of official World Champions, and every champion in the
-- reference list must appear in the mart.
with mart_champions as (

    select standings.season, drivers.driver_ref, standings.points
    from {{ ref('mart_driver_season_standings') }} as standings
    inner join {{ ref('dim_drivers') }} as drivers
        on standings.driver_id = drivers.driver_id
    where standings.championship_position = 1
        and standings.is_season_complete

),

official as (

    select season, driver_ref, points from {{ ref('known_world_champions') }}

)

select
    coalesce(mart_champions.season, official.season) as season,
    mart_champions.driver_ref as mart_driver_ref,
    official.driver_ref as official_driver_ref,
    mart_champions.points as mart_points,
    official.points as official_points
from mart_champions
full outer join official
    on mart_champions.season = official.season
where mart_champions.driver_ref is distinct from official.driver_ref
    or mart_champions.points is distinct from official.points
