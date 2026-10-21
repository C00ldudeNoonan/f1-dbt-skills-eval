-- The confidence interval must contain the point estimate, and every rankable
-- driver must have a unique rank.
select driver_id, adjusted_gap_ci_low, adjusted_qualifying_gap_pct, adjusted_gap_ci_high, overperformance_rank
from {{ ref('mart_driver_car_overperformance') }}
where is_rankable
    and (
        not (adjusted_gap_ci_low <= adjusted_qualifying_gap_pct and adjusted_qualifying_gap_pct <= adjusted_gap_ci_high)
        or overperformance_rank is null
        or overperformance_rank in (
            select overperformance_rank from {{ ref('mart_driver_car_overperformance') }}
            where is_rankable group by 1 having count(*) > 1
        )
    )
