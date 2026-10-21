select
    {{ clean_null('QUALIFYID') }}::int as qualify_id,
    {{ clean_null('RACEID') }}::int as race_id,
    {{ clean_null('DRIVERID') }}::int as driver_id,
    {{ clean_null('CONSTRUCTORID') }}::int as constructor_id,
    {{ clean_null('NUMBER') }}::int as car_number,
    {{ clean_null('POSITION') }}::int as position_number,
    {{ lap_time_to_ms(clean_null('Q1')) }} as q1_ms,
    {{ lap_time_to_ms(clean_null('Q2')) }} as q2_ms,
    {{ lap_time_to_ms(clean_null('Q3')) }} as q3_ms
from ({{ dedupe_raw(source('f1_raw', 'QUALIFYING'), 'QUALIFYID') }})
