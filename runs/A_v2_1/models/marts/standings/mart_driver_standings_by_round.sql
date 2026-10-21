-- Official Drivers' Championship standings after every round, one row per driver
-- per round they appear in. Taken from the published standings snapshot so
-- totals follow each era's rules (dropped scores, shared drives, half points,
-- sprint points from 2021, exclusions). Single source of standings logic:
-- mart_driver_season_standings is derived from this model.
with standings as (

    select * from {{ ref('stg_ergast__driver_standings') }}

),

races as (

    select * from {{ ref('stg_ergast__races') }}

)

select
    races.season,
    races.round,
    standings.race_id,
    standings.driver_id,
    -- Excluded drivers (position_text 'D') have no official championship position.
    iff(regexp_like(standings.position_text, '[0-9]+'), standings.position, null)
        as championship_position,
    standings.position_text,
    standings.points,
    standings.wins
from standings
inner join races
    on standings.race_id = races.race_id
