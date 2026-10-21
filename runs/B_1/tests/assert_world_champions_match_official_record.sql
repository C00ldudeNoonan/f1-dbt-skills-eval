-- Every completed season must have exactly one champion (position 1), and it
-- must be the driver in the independently maintained official record.
with modelled as (
    select season, driver_ref
    from {{ ref('mart_driver_season_standings') }}
    where is_season_complete
      and championship_position = 1
),

official as (
    select season, driver_ref from {{ ref('official_world_champions') }}
),

completed_seasons as (
    select season from {{ ref('int_season_calendar_progress') }} where is_season_complete
)

select
    coalesce(modelled.season, official.season) as season,
    modelled.driver_ref as modelled_champion,
    official.driver_ref as official_champion
from modelled
full outer join official
    on modelled.season = official.season
where (modelled.driver_ref is distinct from official.driver_ref)
  -- a missing seed row only matters for seasons that are actually complete
  and coalesce(modelled.season, official.season) in (select season from completed_seasons)
