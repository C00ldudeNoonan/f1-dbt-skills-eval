-- Every completed season's P1 in mart_driver_season_standings must match the
-- published champion, and every published champion must appear.
with modelled as (
    select standings.season, drivers.driver_ref
    from {{ ref('mart_driver_season_standings') }} as standings
    inner join {{ ref('dim_drivers') }} as drivers
        on standings.driver_id = drivers.driver_id
    where standings.championship_position = 1
        and standings.is_season_complete
),

reference as (
    select season, driver_ref from {{ ref('reference_world_champions') }}
)

select
    coalesce(modelled.season, reference.season) as season,
    modelled.driver_ref                         as modelled_champion,
    reference.driver_ref                        as reference_champion
from modelled
full outer join reference
    on modelled.season = reference.season
where modelled.driver_ref is distinct from reference.driver_ref
