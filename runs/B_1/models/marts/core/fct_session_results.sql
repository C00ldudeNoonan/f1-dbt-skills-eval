{#
    One row per entry in every points-scoring session: Grand Prix races and
    sprints. source_result_id is the id from the source table; ids overlap
    between results and sprint_results, so session_result_id combines it with
    session_type to make a unique key.
#}

with race_results as (
    select * from {{ ref('stg_ergast__results') }}
),

sprint_results as (
    select * from {{ ref('stg_ergast__sprint_results') }}
),

sessions as (
    select
        'race'              as session_type,
        result_id           as source_result_id,
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
    from race_results

    union all

    select
        'sprint'            as session_type,
        sprint_result_id    as source_result_id,
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
    from sprint_results
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
    sessions.session_type || '-' || sessions.source_result_id  as session_result_id,
    sessions.session_type,
    sessions.source_result_id,
    sessions.race_id,
    races.season,
    races.round,
    iff(sessions.session_type = 'sprint', races.sprint_date, races.race_date) as session_date,
    sessions.driver_id,
    sessions.constructor_id,
    constructors.constructor_name,
    sessions.grid,
    sessions.finish_position,
    sessions.position_text,
    sessions.position_order,
    sessions.points,
    sessions.laps,
    status.status,
    coalesce(sessions.finish_position = 1, false)  as is_win,
    coalesce(sessions.finish_position <= 3, false) as is_podium
from sessions
inner join races
    on sessions.race_id = races.race_id
left join constructors
    on sessions.constructor_id = constructors.constructor_id
left join status
    on sessions.status_id = status.status_id
