-- Interval must bracket the score; verdicts must follow from the interval; unrated drivers get no rank.
select driver_id
from {{ ref('mart_driver_teammate_performance') }}
where ci_low_pct > teammate_delta_pct + 1e-9
    or ci_high_pct < teammate_delta_pct - 1e-9
    or (verdict = 'outperforms_teammates' and ci_high_pct >= 0)
    or (verdict = 'underperforms_teammates' and ci_low_pct <= 0)
    or (verdict = 'indistinguishable' and (ci_low_pct > 0 or ci_high_pct < 0))
    or (verdict = 'insufficient_data') <> (rank_among_rated is null)
    or (verdict <> 'insufficient_data' and (stints < 5 or teammates < 3))
