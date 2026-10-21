{{ config(severity='warn') }}
-- Warns when the vendor's two lap time representations disagree. Staging trusts the `time` text.
select race_id, count(*) as laps_disagreeing, min(lap_time_ms - reported_lap_time_ms) as min_diff, max(lap_time_ms - reported_lap_time_ms) as max_diff
from {{ ref('stg_f1__lap_times') }}
where reported_lap_time_ms is not null and abs(lap_time_ms - reported_lap_time_ms) > 1
group by 1
