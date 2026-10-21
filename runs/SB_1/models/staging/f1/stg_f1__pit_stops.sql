-- The vendor dropped the text `duration` column (mixed "23.456" / "1:03.456" formats);
-- `milliseconds` was always consistent with it and is the only source now.
select
    raceid::int                         as race_id,
    driverid::int                       as driver_id,
    stop::int                           as stop_number,
    lap::int                            as lap,
    milliseconds::int                   as duration_ms
from {{ source('f1_raw', 'pit_stops') }}
