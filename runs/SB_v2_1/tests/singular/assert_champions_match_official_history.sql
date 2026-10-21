-- Regression lock: for every complete season the driver in championship position 1 must be the
-- published world champion (seed hand-checked against published history, 1950-2023).
with computed as (
    select standings.season, drivers.driver_ref
    from {{ ref('mart_driver_season_standings') }} as standings
    inner join {{ ref('dim_drivers') }} as drivers using (driver_id)
    inner join {{ ref('int_season_status') }} as status using (season)
    where standings.championship_position = 1
      and status.is_complete
)
select coalesce(computed.season, official.season) as season, computed.driver_ref as modelled, official.driver_ref as official
from computed
full outer join {{ ref('official_world_champions') }} as official
    on computed.season = official.season
where computed.driver_ref is distinct from official.driver_ref
