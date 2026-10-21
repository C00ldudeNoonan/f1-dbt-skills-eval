-- Pole sitter(s) per race have zero gap; every gap is non-negative and the pct matches ms.
select race_id, driver_id
from {{ ref('fct_qualifying') }}
where gap_to_pole_ms < 0
    or (best_time_ms is null) <> (gap_to_pole_ms is null)
    or best_time_ms > coalesce(q1_ms, best_time_ms)
    or best_time_ms > coalesce(q2_ms, best_time_ms)
    or best_time_ms > coalesce(q3_ms, best_time_ms)
