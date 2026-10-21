select
    trim(session_key) as session_key,
    trim(driver_key) as driver_key,
    trim(team_name) as team_name,
    grid_position::integer as grid,
    try_to_number(trim(position))::integer as finish_position,
    upper(trim(position)) as position_text,
    points::number(8, 2) as points
from {{ source('f1_raw', 'vb_results') }}
{{ dedupe(['session_key', 'driver_key']) }}
