-- Reconciles the what-if scorer against real history. In 2010-2013 and
-- 2015-2018 the official system was exactly fia_2010 (25-18-15-...-1, no
-- sprints, no fastest-lap point). 2014 is left out because of its double
-- points finale. In those seasons the re-scored points must equal the
-- official final points for every driver.

with official as (
    select season, driver_id, points
    from {{ ref('mart_driver_season_standings') }}
    where season between 2010 and 2018
        and season <> 2014
),

alternative as (
    select season, driver_id, alt_points
    from {{ ref('mart_alt_points_standings_by_system') }}
    where points_system = 'fia_2010'
        and season between 2010 and 2018
        and season <> 2014
)

select
    coalesce(official.season, alternative.season) as season,
    coalesce(official.driver_id, alternative.driver_id) as driver_id,
    official.points as official_points,
    alternative.alt_points
from official
full outer join alternative
    on official.season = alternative.season
    and official.driver_id = alternative.driver_id
where official.points is distinct from alternative.alt_points
