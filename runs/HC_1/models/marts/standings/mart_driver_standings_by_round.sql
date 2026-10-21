-- Official championship standings after every round a driver appears in the standings.
-- Source of the season standings mart and of the season-by-season charts.
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
    standings.position as championship_position,
    standings.points,
    standings.wins
from standings
inner join races
    on standings.race_id = races.race_id
