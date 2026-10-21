-- One row per entry in a Grand Prix or a sprint, classified or not. Use
-- session_type to separate them; fct_results is the Grand Prix-only view.

select
    session_type || '-' || source_result_id as session_result_key,
    session_type,
    source_result_id,
    race_id,
    season,
    round,
    race_date,
    driver_id,
    constructor_id,
    constructor_name,
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
    fastest_lap_time_ms
from {{ ref('int_f1__session_results') }}
