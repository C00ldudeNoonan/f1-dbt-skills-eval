-- Every Vendor B result must land on one of our sessions and drivers through
-- the crosswalks. An unmapped row would silently drop out of the discrepancy
-- mart, so this fails instead.
select
    vendor_results.session_key,
    vendor_results.driver_key
from {{ ref('stg_vendor_b__results') }} as vendor_results
left join {{ ref('dim_session_crosswalk') }} as sessions
    on vendor_results.session_key = sessions.session_key
left join {{ ref('dim_driver_crosswalk') }} as drivers
    on vendor_results.driver_key = drivers.driver_key
where sessions.race_id is null
    or drivers.driver_id is null
