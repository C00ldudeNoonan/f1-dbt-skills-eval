select qualify_id
from {{ ref('fct_qualifying') }}
where gap_to_pole_ms < 0
    or gap_to_pole_pct < 0
    or (best_time_ms is not null and gap_to_pole_ms is null)
