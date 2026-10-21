select
    session_key::integer                                            as session_key,
    trim(driver_key)                                                as driver_key,
    trim(team_name)                                                 as team_name,
    grid_position::integer                                          as grid,
    -- Numeric POSITION is a classified finish; DNF / DSQ are not classified.
    iff(regexp_like(trim(position), '^[0-9]+$'), trim(position)::integer, null) as finish_position,
    trim(position)                                                  as position_text,
    points::number(10, 2)                                           as points
from {{ source('vendor_b', 'vb_results') }}
{{ dedupe('session_key, driver_key', 'driver_key') }}
