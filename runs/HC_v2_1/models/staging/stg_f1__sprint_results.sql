select
    {{ null_if_sentinel('RESULTID') }}::integer as result_id,
    {{ null_if_sentinel('RACEID') }}::integer as race_id,
    {{ null_if_sentinel('DRIVERID') }}::integer as driver_id,
    {{ null_if_sentinel('CONSTRUCTORID') }}::integer as constructor_id,
    {{ null_if_sentinel('GRID') }}::integer as grid,
    {{ null_if_sentinel('POSITION') }}::integer as position,
    {{ null_if_sentinel('POSITIONTEXT') }} as position_text,
    {{ null_if_sentinel('POSITION_ORDER') }}::integer as position_order,
    {{ null_if_sentinel('POINTS') }}::numeric(6, 2) as points,
    {{ null_if_sentinel('LAPS') }}::integer as laps,
    {{ null_if_sentinel('MILLISECONDS') }}::integer as race_time_ms,
    {{ lap_time_to_ms(null_if_sentinel('FASTESTLAPTIME')) }} as fastest_lap_time_ms,
    {{ null_if_sentinel('STATUSID') }}::integer as status_id
from {{ source('f1_raw', 'SPRINT_RESULTS') }}
