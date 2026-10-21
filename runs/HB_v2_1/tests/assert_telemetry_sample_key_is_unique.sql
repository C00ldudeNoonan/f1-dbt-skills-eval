{{ config(tags=['reconciliation']) }}
{#
    Reconciliation check, not part of routine runs. Each sample is keyed by race, driver, lap and
    sample index. A duplicate would double count laps in the summary.
#}
select
    race_id,
    driver_id,
    lap,
    sample_index,
    count(*) as copies

from {{ ref('fct_telemetry') }}
group by race_id, driver_id, lap, sample_index
having count(*) > 1
