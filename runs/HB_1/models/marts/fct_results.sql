-- One row per Grand Prix result entry. Sprint results are excluded because they come from a separate source table.
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
    results.finish_position_text,
    results.position_order,
    results.points,
    results.laps,
    status.status,
    coalesce(results.finish_position = 1, false) as is_win,
    coalesce(results.finish_position between 1 and 3, false) as is_podium,
    {{ lap_time_to_ms('results.fastest_lap_time_text') }} as fastest_lap_time_ms
from results
inner join races
    on races.race_id = results.race_id
inner join constructors
    on constructors.constructor_id = results.constructor_id
inner join status
    on status.status_id = results.status_id
