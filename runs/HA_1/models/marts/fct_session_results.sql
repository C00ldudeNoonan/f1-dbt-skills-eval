-- One row per driver entry in a Grand Prix or a sprint.
-- session_result_key is unique across both sources, because each source table has its own result_id sequence.

with race_results as (

    select
        'race' as session_type,
        result_id as source_result_id,
        race_id,
        driver_id,
        constructor_id,
        grid,
        finish_position,
        position_text,
        position_order,
        points,
        laps,
        status_id
    from {{ ref('stg_f1__results') }}

),

sprint_results as (

    select
        'sprint' as session_type,
        result_id as source_result_id,
        race_id,
        driver_id,
        constructor_id,
        grid,
        finish_position,
        position_text,
        position_order,
        points,
        laps,
        status_id
    from {{ ref('stg_f1__sprint_results') }}

),

all_sessions as (

    select * from race_results
    union all
    select * from sprint_results

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
    all_sessions.session_type || '-' || all_sessions.source_result_id as session_result_key,
    all_sessions.session_type,
    all_sessions.source_result_id,
    all_sessions.race_id,
    races.season,
    races.round,
    races.race_date,
    all_sessions.driver_id,
    all_sessions.constructor_id,
    constructors.constructor_name,
    all_sessions.grid,
    all_sessions.finish_position,
    all_sessions.position_text,
    all_sessions.position_order,
    all_sessions.points,
    all_sessions.laps,
    status.status,
    coalesce(all_sessions.finish_position = 1, false) as is_win,
    coalesce(all_sessions.finish_position <= 3, false) as is_podium
from all_sessions
inner join races
    on all_sessions.race_id = races.race_id
left join constructors
    on all_sessions.constructor_id = constructors.constructor_id
left join status
    on all_sessions.status_id = status.status_id
