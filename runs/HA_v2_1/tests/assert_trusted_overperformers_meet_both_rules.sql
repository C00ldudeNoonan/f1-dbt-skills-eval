{#
    A driver can only be a trusted overperformer with enough shared races and an interval entirely
    above 50%. Returns any driver that breaks either rule.
#}
select driver_id
from {{ ref('mart_driver_car_performance') }}
where trusted_overperformer
    and (not is_eligible or race_win_rate_ci_low <= 0.5)
