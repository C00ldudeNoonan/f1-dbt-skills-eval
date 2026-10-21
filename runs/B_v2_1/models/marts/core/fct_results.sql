with results as (
    select * from {{ ref('stg_ergast__results') }}
),

races as (
    select * from {{ ref('stg_ergast__races') }}
),

constructors as (
    select * from {{ ref('stg_ergast__constructors') }}
),

status as (
    select * from {{ ref('stg_ergast__status') }}
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
    results.car_number,
    results.grid,
    results.finish_position,
    results.position_text,
    results.position_order,
    results.points,
    results.laps,
    results.status_id,
    status.status,
    coalesce(results.finish_position = 1, false)    as is_win,
    coalesce(results.finish_position <= 3, false)   as is_podium,
    results.race_time_ms,
    results.fastest_lap_number,
    results.fastest_lap_rank,
    results.fastest_lap_time_ms
from results
inner join races
    on results.race_id = races.race_id
left join constructors
    on results.constructor_id = constructors.constructor_id
left join status
    on results.status_id = status.status_id
