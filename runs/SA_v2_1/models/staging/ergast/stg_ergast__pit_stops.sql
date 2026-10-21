-- Stop duration comes from the integer `milliseconds` column (the vendor's text `duration`
-- column, which switched to m:ss.mmm over a minute, has been dropped upstream).
select distinct
    raceid::integer as race_id,
    driverid::integer as driver_id,
    stop::integer as stop_number,
    lap::integer as lap,
    {{ clean_text('milliseconds') }}::integer as duration_ms
from {{ source('ergast', 'pit_stops') }}
