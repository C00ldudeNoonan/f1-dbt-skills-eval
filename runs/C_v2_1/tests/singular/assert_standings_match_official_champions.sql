-- Reconciles the modelled championship against published history: for every
-- completed season, P1 in mart_driver_season_standings must be the official
-- champion with the official points total. Seasons still in progress in the
-- data (not marked complete) are skipped.

with champions as (
    select * from {{ ref('world_drivers_champions') }}
),

modelled as (
    select
        standings.season,
        drivers.driver_ref,
        standings.points
    from {{ ref('mart_driver_season_standings') }} as standings
    inner join {{ ref('dim_drivers') }} as drivers
        on standings.driver_id = drivers.driver_id
    where standings.championship_position = 1
        and standings.is_season_complete
)

select
    coalesce(champions.season, modelled.season) as season,
    champions.driver_ref as official_champion,
    champions.points as official_points,
    modelled.driver_ref as modelled_champion,
    modelled.points as modelled_points
from champions
full outer join modelled
    on champions.season = modelled.season
where modelled.season is not null
    and (
        champions.season is null
        or champions.driver_ref <> modelled.driver_ref
        or champions.points <> modelled.points
    )
