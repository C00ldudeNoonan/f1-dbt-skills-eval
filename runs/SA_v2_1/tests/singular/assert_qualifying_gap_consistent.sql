select qualify_id
from {{ ref('fct_qualifying') }}
where (best_time_ms is null and (gap_to_pole_ms is not null or gap_to_pole_pct is not null))
    or gap_to_pole_ms < 0
    or best_time_ms > coalesce(q1_ms, best_time_ms)
