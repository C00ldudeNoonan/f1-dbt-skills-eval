select
    resultid::integer as result_id,
    raceid::integer as race_id,
    driverid::integer as driver_id,
    constructorid::integer as constructor_id,
    grid::integer as grid,
    {{ finish_position('position', 'positiontext') }} as finish_position,
    position_order::integer as position_order,
    points::number(8, 2) as points
from {{ source('f1_raw', 'sprint_results') }}
{{ dedupe(['result_id']) }}
