{#
    Full-table uniqueness of telemetry keys. It scans every sample, so it is tagged weekly_full_scan and kept out
    of routine runs (dbt build --exclude tag:weekly_full_scan). The routine test in the YAML covers recent loads.
#}
{{ config(tags=['weekly_full_scan']) }}
select race_id, driver_id, lap, sample_index
from {{ ref('fct_telemetry') }}
group by race_id, driver_id, lap, sample_index
having count(*) > 1
