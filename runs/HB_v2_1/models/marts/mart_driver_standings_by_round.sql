{#
    Official driver championship standings after every round in which a driver appears,
    taken from the official DRIVER_STANDINGS snapshot. This is the single source for
    standings. mart_driver_season_standings is derived from it.
#}
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
    standings.position as championship_position,
    standings.points,
    standings.wins

from standings
inner join races
    on standings.race_id = races.race_id
