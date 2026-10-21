-- One row per driver per round in which the driver appears in the official standings.
-- This is the full history of championship standings. The season view is derived from it.
with standings as (

    select * from {{ ref('stg_f1__driver_standings') }}

),

races as (

    select * from {{ ref('stg_f1__races') }}

)

select
    races.season,
    races.round,
    standings.race_id,
    standings.driver_id,
    standings.championship_position,
    standings.points,
    standings.wins
from standings
inner join races
    on races.race_id = standings.race_id
