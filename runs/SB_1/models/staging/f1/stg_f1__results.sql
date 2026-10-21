select
    resultid::int                                           as result_id,
    raceid::int                                             as race_id,
    driverid::int                                           as driver_id,
    constructorid::int                                      as constructor_id,
    statusid::int                                           as status_id,
    {{ clean_null('grid') }}::int                           as grid,
    {{ clean_null('position') }}::int                       as finish_position,
    position_order::int                                     as position_order,
    points::number(6, 2)                                    as points,
    {{ clean_null('laps') }}::int                           as laps,
    {{ lap_time_to_ms(clean_null('fastestlaptime')) }}      as fastest_lap_time_ms
from {{ source('f1_raw', 'results') }}
