select
    {{ clean_null('RESULTID') }}::int as result_id,
    {{ clean_null('RACEID') }}::int as race_id,
    {{ clean_null('DRIVERID') }}::int as driver_id,
    {{ clean_null('CONSTRUCTORID') }}::int as constructor_id,
    {{ clean_null('NUMBER') }}::int as car_number,
    {{ clean_null('GRID') }}::int as grid,
    {{ clean_null('POSITION') }}::int as position_number,
    {{ clean_null('POSITIONTEXT') }} as position_text,
    {{ clean_null('POSITION_ORDER') }}::int as position_order,
    {{ clean_null('POINTS') }}::decimal(6, 2) as points,
    {{ clean_null('LAPS') }}::int as laps,
    {{ clean_null('MILLISECONDS') }}::int as race_time_ms,
    {{ clean_null('RANK') }}::int as fastest_lap_rank,
    {{ lap_time_to_ms(clean_null('FASTESTLAPTIME')) }} as fastest_lap_time_ms,
    {{ clean_null('FASTESTLAPSPEED') }}::decimal(7, 3) as fastest_lap_speed,
    {{ clean_null('STATUSID') }}::int as status_id
from ({{ dedupe_raw(source('f1_raw', 'RESULTS'), 'RESULTID') }})
