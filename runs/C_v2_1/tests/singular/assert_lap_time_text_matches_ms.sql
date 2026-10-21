{{ config(severity='warn') }}

-- Vendor consistency check: a lap's `time` text and its `milliseconds`
-- should describe the same lap. The project uses milliseconds. A mismatch
-- means the vendor corrected one field without the other (race 1142 has 215
-- such laps from a correction reissued on 2026-10-21).
select
    raceid,
    count(*) as mismatched_laps,
    min(milliseconds::integer - {{ time_to_ms('time') }}) as min_difference_ms,
    max(milliseconds::integer - {{ time_to_ms('time') }}) as max_difference_ms
from {{ source('f1_raw', 'lap_timing') }}
where {{ time_to_ms('time') }} <> milliseconds::integer
group by raceid
