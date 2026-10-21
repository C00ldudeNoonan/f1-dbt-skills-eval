{#
    Every Vendor B result must map to one of our sessions and drivers. A row here means the
    comparison silently skipped it, so this test fails the build.
#}
select results.session_key, results.driver_key
from {{ ref('stg_vb__results') }} as results
left join {{ ref('dim_session_crosswalk') }} as sessions
    on results.session_key = sessions.session_key
left join {{ ref('dim_driver_crosswalk') }} as drivers
    on results.driver_key = drivers.driver_key
where sessions.race_id is null
    or drivers.driver_id is null
