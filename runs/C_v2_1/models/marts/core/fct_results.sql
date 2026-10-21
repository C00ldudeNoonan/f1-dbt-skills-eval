-- Grand Prix results only. Sprints are in fct_session_results.

select
    source_result_id as result_id,
    race_id,
    season,
    round,
    race_date,
    driver_id,
    constructor_id,
    constructor_name,
    car_number,
    grid,
    position_text,
    finish_position,
    position_order,
    points,
    laps,
    status,
    is_win,
    is_podium,
    race_time_ms,
    fastest_lap_number,
    fastest_lap_rank,
    fastest_lap_time_ms
from {{ ref('int_f1__session_results') }}
where session_type = 'race'
