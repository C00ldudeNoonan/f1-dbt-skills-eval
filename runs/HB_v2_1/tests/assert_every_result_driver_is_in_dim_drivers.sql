{#
    No result is lost to a missing driver record. Every fct_results row has a
    matching dim_drivers row, real or placeholder.
#}
select results.result_id
from {{ ref('fct_results') }} as results
left join {{ ref('dim_drivers') }} as drivers
    on results.driver_id = drivers.driver_id
where drivers.driver_id is null
