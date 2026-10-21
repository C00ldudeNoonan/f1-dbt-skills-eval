{#
    Every Vendor B result must map to one of our sessions and drivers. An unmapped result would be missing from the
    discrepancy mart without an error, so this fails it loudly.
#}
select
    results.session_key,
    results.driver_key
from {{ ref('stg_f1__vb_results') }} as results
left join {{ ref('dim_session_crosswalk') }} as sessions
    on results.session_key = sessions.session_key
left join {{ ref('dim_driver_crosswalk') }} as drivers
    on results.driver_key = drivers.driver_key
where sessions.race_id is null
    or drivers.driver_id is null
