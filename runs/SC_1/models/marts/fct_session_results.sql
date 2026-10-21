-- Grand Prix and sprint results in one table. Raw result ids are NOT unique across the two
-- source tables (every sprint resultid also exists in results), so session_result_id is the key.
with race_results as (

    select
        'race' as session_type,
        result_id as source_result_id,
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
        is_win,
        is_podium,
        fastest_lap_time_ms
    from {{ ref('fct_results') }}

),

sprint_results as (

    select
        'sprint' as session_type,
        sprint.result_id as source_result_id,
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
        statuses.status,
        coalesce(sprint.finish_position = 1, false) as is_win,
        coalesce(sprint.finish_position between 1 and 3, false) as is_podium,
        sprint.fastest_lap_time_ms
    from {{ ref('stg_f1__sprint_results') }} as sprint
    inner join {{ ref('stg_f1__races') }} as races on sprint.race_id = races.race_id
    inner join {{ ref('stg_f1__constructors') }} as constructors on sprint.constructor_id = constructors.constructor_id
    inner join {{ ref('stg_f1__status') }} as statuses on sprint.status_id = statuses.status_id

),

unioned as (

    select * from race_results
    union all
    select * from sprint_results

)

select
    session_type || '-' || source_result_id as session_result_id,
    *
from unioned
