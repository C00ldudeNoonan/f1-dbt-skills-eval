-- Grain: one row per entry per session, across Grand Prix races and sprints.
-- (session_type, source_result_id) is the key: result ids are only unique within each source table.
with race_sessions as (
    select
        'race' as session_type,
        result_id as source_result_id,
        race_id,
        season,
        round,
        race_date,
        driver_id,
        constructor_id,
        grid,
        finish_position,
        position_order,
        points,
        laps
    from {{ ref('fct_results') }}
),

sprint_sessions as (
    select
        'sprint' as session_type,
        sprints.sprint_result_id as source_result_id,
        sprints.race_id,
        races.season,
        races.round,
        races.race_date,
        sprints.driver_id,
        sprints.constructor_id,
        sprints.grid,
        -- same classification rule as fct_results
        case
            when sprints.position is not null or regexp_like(sprints.position_text, '^[0-9]+$')
                then sprints.position_order
        end as finish_position,
        sprints.position_order,
        sprints.points,
        sprints.laps
    from {{ ref('stg_f1__sprint_results') }} as sprints
    inner join {{ ref('stg_f1__races') }} as races on races.race_id = sprints.race_id
),

unioned as (
    select * from race_sessions
    union all
    select * from sprint_sessions
)

select
    session_type,
    source_result_id,
    race_id,
    season,
    round,
    race_date,
    driver_id,
    constructor_id,
    grid,
    finish_position,
    position_order,
    points,
    laps,
    coalesce(finish_position = 1, false) as is_win
from unioned
