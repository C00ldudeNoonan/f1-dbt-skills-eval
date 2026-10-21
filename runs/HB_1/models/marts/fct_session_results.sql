-- One row per driver entry per session: Grand Prix races and sprint races.
-- source_result_id is the id in the session's own source table. Result ids are not unique across
-- sessions, so (session_type, source_result_id) is the key.
with race_results as (

    select
        'race' as session_type,
        result_id as source_result_id,
        race_id,
        driver_id,
        constructor_id,
        grid,
        finish_position,
        position_order,
        points,
        laps,
        status_id
    from {{ ref('stg_f1__results') }}

),

sprint_results as (

    select
        'sprint' as session_type,
        sprint_result_id as source_result_id,
        race_id,
        driver_id,
        constructor_id,
        grid,
        finish_position,
        position_order,
        points,
        laps,
        status_id
    from {{ ref('stg_f1__sprint_results') }}

),

sessions as (

    select * from race_results
    union all
    select * from sprint_results

),

races as (

    select * from {{ ref('stg_f1__races') }}

)

select
    sessions.session_type,
    sessions.source_result_id,
    sessions.race_id,
    races.season,
    races.round,
    sessions.driver_id,
    sessions.constructor_id,
    sessions.grid,
    sessions.finish_position,
    sessions.position_order,
    sessions.points,
    sessions.laps,
    coalesce(sessions.finish_position = 1, false) as is_win
from sessions
inner join races
    on races.race_id = sessions.race_id
