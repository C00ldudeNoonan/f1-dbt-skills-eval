{#
  Official drivers' championship standings after every round: one row per
  driver per round in which they appear in the official standings. This is the
  single place standings logic lives; mart_driver_season_standings is the
  latest-completed-round slice of this model.
#}

with standings as (
    select * from {{ ref('stg_ergast__driver_standings') }}
),

races as (
    select race_id, season, round, race_date from {{ ref('stg_ergast__races') }}
)

select
    races.season,
    races.round,
    standings.race_id,
    races.race_date,
    standings.driver_id,
    standings.championship_position,
    standings.position_text,
    standings.points,
    standings.wins,
    standings.position_text = 'D'   as is_excluded_from_championship
from standings
inner join races
    on standings.race_id = races.race_id
