-- Every completed season's P1 must match the independently sourced list of
-- world champions (surname + official points). Also fails if a completed
-- season has no champion row in the reference seed, or vice versa.

with champions as (
    select
        standings.season,
        drivers.surname,
        standings.points
    from {{ ref('mart_driver_season_standings') }} as standings
    inner join {{ ref('stg_ergast__drivers') }} as drivers
        on standings.driver_id = drivers.driver_id
    where standings.is_season_complete
      and standings.championship_position = 1
),

reference as (
    select * from {{ ref('historical_world_champions') }}
)

select
    coalesce(champions.season, reference.season) as season,
    champions.surname,
    champions.points,
    reference.champion_surname,
    reference.champion_points
from champions
full outer join reference
    on champions.season = reference.season
where champions.season is null
   or reference.season is null
   or champions.surname <> reference.champion_surname
   or champions.points <> reference.champion_points
