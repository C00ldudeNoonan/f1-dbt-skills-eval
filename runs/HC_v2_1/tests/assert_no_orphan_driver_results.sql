{#
    Results or qualifying entries whose driver has no record in drivers yet.
    These are not lost: they stay in fct_results and dim_drivers carries a placeholder row.
    The test warns rather than fails, so a late driver record does not block the build.
    Each row returned is one orphan driver with the number of results and qualifying entries waiting.
#}
{{ config(severity='warn') }}

select
    driver_id,
    orphan_result_count,
    orphan_qualifying_count,
    orphan_standings_count
from {{ ref('int_orphan_drivers') }}
where orphan_result_count > 0
    or orphan_qualifying_count > 0
    or orphan_standings_count > 0
