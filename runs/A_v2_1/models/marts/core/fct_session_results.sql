-- One row per result entry across Grand Prix and sprint sessions.
-- Grand Prix and sprint result ids come from different source tables and can
-- collide, so the key is (session_type, source_result_id).
with sessions as (

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
        status_id,
        fastest_lap_time_ms
    from {{ ref('stg_ergast__results') }}

    union all

    select
        'sprint' as session_type,
        sprint_result_id as source_result_id,
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

)

select
    sessions.session_type || '-' || sessions.source_result_id as session_result_key,
    sessions.session_type,
    sessions.source_result_id,
    sessions.race_id,
    races.season,
    races.round,
    case sessions.session_type
        when 'sprint' then races.sprint_date
        else races.race_date
    end as session_date,
    sessions.driver_id,
    sessions.constructor_id,
    sessions.grid,
    sessions.finish_position,
    sessions.position_text,
    sessions.position_order,
    sessions.points,
    sessions.laps,
    sessions.status_id,
    sessions.finish_position is not null as is_classified,
    coalesce(sessions.finish_position = 1, false) as is_win,
    coalesce(sessions.finish_position <= 3, false) as is_podium,
    sessions.fastest_lap_time_ms
from sessions
inner join {{ ref('stg_ergast__races') }} as races
    on sessions.race_id = races.race_id
