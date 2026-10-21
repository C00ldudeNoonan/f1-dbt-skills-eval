select
    {{ clean_null('RACEID') }}::int as race_id,
    {{ clean_null('DRIVERID') }}::int as driver_id,
    {{ clean_null('STOP') }}::int as stop_number,
    {{ clean_null('LAP') }}::int as lap,
    {{ clean_null('TIME') }} as pit_time_text,
    {{ clean_null('MILLISECONDS') }}::int as duration_ms
from ({{ dedupe_raw(source('f1_raw', 'PIT_STOPS')) }})
