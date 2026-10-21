with source as (

    select * from {{ source('f1_raw', 'results') }}

)

select
    resultid::integer as result_id,
    raceid::integer as race_id,
    driverid::integer as driver_id,
    constructorid::integer as constructor_id,
    {{ null_marker('number') }}::integer as car_number,
    grid::integer as grid,
    {{ null_marker('position') }}::integer as finish_position,
    positiontext as position_text,
    position_order::integer as position_order,
    points::number(6, 2) as points,
    laps::integer as laps,
    statusid::integer as status_id,
    {{ lap_time_to_ms('fastestlaptime') }} as fastest_lap_time_ms
from source
