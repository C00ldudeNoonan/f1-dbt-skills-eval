-- Grand Prix and sprint entries in one table. Source result ids are numbered independently in
-- `results` and `sprint_results` (sprint ids 1-360 collide with Grand Prix ids), so the unique
-- key is (session_type, source_result_id), exposed as `session_result_id`.
with races as (

    select * from {{ ref('stg_f1__races') }}

),

constructors as (

    select * from {{ ref('stg_f1__constructors') }}

),

status as (

    select * from {{ ref('stg_f1__status') }}

),

sprints as (

    select
        'sprint'                                        as session_type,
        sprint.result_id                                as source_result_id,
        sprint.race_id,
        races.season,
        races.round,
        races.race_date,
        sprint.driver_id,
        sprint.constructor_id,
        constructors.constructor_name,
        sprint.grid,
        sprint.finish_position,
        sprint.position_order,
        sprint.points,
        sprint.laps,
        status.status,
        sprint.fastest_lap_time_ms
    from {{ ref('stg_f1__sprint_results') }} as sprint
    inner join races on sprint.race_id = races.race_id
    inner join constructors on sprint.constructor_id = constructors.constructor_id
    inner join status on sprint.status_id = status.status_id

),

grands_prix as (

    select
        'race'                  as session_type,
        result_id               as source_result_id,
        race_id,
        season,
        round,
        race_date,
        driver_id,
        constructor_id,
        constructor_name,
        grid,
        finish_position,
        position_order,
        points,
        laps,
        status,
        fastest_lap_time_ms
    from {{ ref('fct_results') }}

),

unioned as (

    select * from grands_prix
    union all
    select * from sprints

)

select
    session_type || '-' || source_result_id             as session_result_id,
    *,
    coalesce(finish_position = 1, false)                as is_win,
    coalesce(finish_position <= 3, false)               as is_podium
from unioned
