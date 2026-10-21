{{ config(severity='warn') }}
{#
    Results whose driver has no record in the drivers feed yet. These are kept in
    fct_results (is_orphan_driver) and get a placeholder in dim_drivers. This test warns,
    so the count shows in every build without failing it.
#}
select driver_id, result_rows
from {{ ref('int_orphan_driver_ids') }}
where result_rows > 0
