with results as (

    select * from {{ ref('stg_f1__results') }}

),

races as (

    select * from {{ ref('stg_f1__races') }}

),

constructors as (

    select * from {{ ref('stg_f1__constructors') }}

),

status as (

    select * from {{ ref('stg_f1__status') }}

)

select
    results.result_id,
    results.race_id,
    races.season,
    races.round,
    races.race_date,
    results.driver_id,
    results.constructor_id,
    constructors.constructor_name,
    results.grid,
    results.finish_position,
    results.position_order,
    results.points,
    results.laps,
    status.status,
    coalesce(results.finish_position = 1, false)    as is_win,
    coalesce(results.finish_position <= 3, false)   as is_podium,
    results.fastest_lap_time_ms
from results
inner join races on results.race_id = races.race_id
inner join constructors on results.constructor_id = constructors.constructor_id
inner join status on results.status_id = status.status_id
