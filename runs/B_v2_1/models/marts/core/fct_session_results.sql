{#-
  One row per result entry across Grand Prix and sprint sessions.
  Grain: (session_type, source_result_id). Source ids are only unique within
  their own table, so session_result_id combines the two.
-#}
with grand_prix as (
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
        status_id,
        fastest_lap_time_ms
    from {{ ref('stg_ergast__results') }}
),

sprints as (
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
        status_id,
        fastest_lap_time_ms
    from {{ ref('stg_ergast__sprint_results') }}
),

sessions as (
    select * from grand_prix
    union all
    select * from sprints
)

select
    sessions.session_type || '-' || sessions.source_result_id   as session_result_id,
    sessions.session_type,
    sessions.source_result_id,
    sessions.race_id,
    races.season,
    races.round,
    iff(sessions.session_type = 'sprint', races.sprint_date, races.race_date) as session_date,
    sessions.driver_id,
    sessions.constructor_id,
    sessions.grid,
    sessions.finish_position,
    sessions.position_text,
    sessions.position_order,
    sessions.points,
    sessions.laps,
    sessions.status_id,
    status.status,
    coalesce(sessions.finish_position = 1, false)               as is_win,
    coalesce(sessions.finish_position <= 3, false)              as is_podium,
    sessions.fastest_lap_time_ms
from sessions
inner join {{ ref('stg_ergast__races') }} as races
    on sessions.race_id = races.race_id
left join {{ ref('stg_ergast__status') }} as status
    on sessions.status_id = status.status_id
