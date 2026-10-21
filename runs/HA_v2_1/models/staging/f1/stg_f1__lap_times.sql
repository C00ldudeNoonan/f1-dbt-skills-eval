select
    {{ clean_null('RACEID') }}::int as race_id,
    {{ clean_null('DRIVERID') }}::int as driver_id,
    {{ clean_null('LAP') }}::int as lap,
    {{ clean_null('POSITION') }}::int as position_number,
    {{ clean_null('TIME') }} as lap_time_text,
    {{ clean_null('MILLISECONDS') }}::int as lap_time_ms
from ({{ dedupe_raw(source('f1_raw', 'LAP_TIMING')) }})
