-- The raw `milliseconds` column and the `time` text can disagree (race 1142: 215 laps off by +137 ms in
-- `milliseconds`, while the per-driver sum of `time` reconciles exactly to the official race time).
-- `time` is therefore authoritative; `milliseconds` is only a fallback when `time` is missing, and the
-- `reported_lap_time_ms` column keeps the raw value so the disagreement is testable.
select
    {{ clean_int('raceid') }} as race_id,
    {{ clean_int('driverid') }} as driver_id,
    {{ clean_int('lap') }} as lap,
    {{ clean_int('position') }} as position,
    coalesce({{ lap_time_to_ms('time') }}, {{ clean_int('milliseconds') }}) as lap_time_ms,
    {{ clean_int('milliseconds') }} as reported_lap_time_ms
from {{ source('f1_raw', 'lap_times') }}
qualify row_number() over (partition by race_id, driver_id, lap order by race_id) = 1
