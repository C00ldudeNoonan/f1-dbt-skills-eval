{#
    Public interface (contract enforced): column names and types are a
    promise to downstream projects. Changing them needs a new model version.

    One row per Grand Prix result entry. Sprint results are deliberately
    excluded (see stg_ergast__sprint_results).
#}

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
    cast(results.result_id as integer)                      as result_id,
    cast(results.race_id as integer)                        as race_id,
    cast(races.season as integer)                           as season,
    cast(races.round as integer)                            as round,
    cast(races.race_date as date)                           as race_date,
    cast(races.race_name as varchar)                        as race_name,
    cast(races.circuit_id as integer)                       as circuit_id,
    cast(results.driver_id as integer)                      as driver_id,
    cast(results.constructor_id as integer)                 as constructor_id,
    cast(constructors.constructor_name as varchar)          as constructor_name,
    cast(results.car_number as integer)                     as car_number,
    cast(results.grid as integer)                           as grid,
    cast(results.finish_position as integer)                as finish_position,
    cast(results.position_text as varchar)                  as position_text,
    cast(results.position_order as integer)                 as position_order,
    cast(results.points as number(10, 2))                   as points,
    cast(results.laps as integer)                           as laps,
    cast(status.status as varchar)                          as status,
    coalesce(results.finish_position = 1, false)            as is_win,
    coalesce(results.finish_position <= 3, false)           as is_podium,
    cast(results.race_time_ms as integer)                   as race_time_ms,
    cast(results.fastest_lap_number as integer)             as fastest_lap_number,
    cast(results.fastest_lap_rank as integer)               as fastest_lap_rank,
    cast(results.fastest_lap_time_ms as integer)            as fastest_lap_time_ms
from results
inner join races
    on results.race_id = races.race_id
left join constructors
    on results.constructor_id = constructors.constructor_id
left join status
    on results.status_id = status.status_id
