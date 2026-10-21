select
    {{ null_if_sentinel('QUALIFYID') }}::integer as qualify_id,
    {{ null_if_sentinel('RACEID') }}::integer as race_id,
    {{ null_if_sentinel('DRIVERID') }}::integer as driver_id,
    {{ null_if_sentinel('CONSTRUCTORID') }}::integer as constructor_id,
    {{ null_if_sentinel('NUMBER') }}::integer as car_number,
    {{ null_if_sentinel('POSITION') }}::integer as position,
    {{ lap_time_to_ms(null_if_sentinel('Q1')) }} as q1_ms,
    {{ lap_time_to_ms(null_if_sentinel('Q2')) }} as q2_ms,
    {{ lap_time_to_ms(null_if_sentinel('Q3')) }} as q3_ms
from {{ source('f1_raw', 'QUALIFYING') }}
