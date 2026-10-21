{#-
  Official drivers' championship after every round: one row per driver per
  round they appear in the published cumulative standings. Points include
  drop-score rules (pre-1991) and sprint points (2021+) as published.
-#}
select
    races.season,
    races.round,
    standings.race_id,
    standings.driver_id,
    -- Excluded drivers (Schumacher 1997) have no official championship position.
    iff(standings.is_excluded, null, standings.position)    as championship_position,
    standings.points,
    standings.wins,
    standings.is_excluded
from {{ ref('stg_ergast__driver_standings') }} as standings
inner join {{ ref('stg_ergast__races') }} as races
    on standings.race_id = races.race_id
