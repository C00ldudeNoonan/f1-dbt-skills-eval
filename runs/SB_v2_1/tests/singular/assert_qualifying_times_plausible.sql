{{ config(severity='warn') }}
-- Known raw quirk: 2005 race 255 has a Q1 of 16:42.640. Warn on any qualifying time over 5 minutes.
select qualify_id, race_id, driver_id, greatest(coalesce(q1_ms, 0), coalesce(q2_ms, 0), coalesce(q3_ms, 0)) as slowest_ms
from {{ ref('fct_qualifying') }}
where greatest(coalesce(q1_ms, 0), coalesce(q2_ms, 0), coalesce(q3_ms, 0)) > 300000
