select
    resultid::int as result_id,
    raceid::int as race_id,
    driverid::int as driver_id,
    constructorid::int as constructor_id,
    statusid::int as status_id,
    grid::int as grid,
    -- `position` is null for unclassified entries; positiontext is not used because it
    -- holds codes (R, D, W...) and, in two 2005 US GP rows, a number with no classification.
    {{ clean_null('position') }}::int as finish_position,
    position_order::int as position_order,
    points::number(10, 2) as points,
    laps::int as laps,
    {{ lap_time_to_ms(clean_null('fastestlaptime')) }} as fastest_lap_time_ms
from {{ source('f1_raw', 'results') }}
