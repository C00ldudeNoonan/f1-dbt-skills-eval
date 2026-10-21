-- Every Vendor B result must map to one of our sessions and drivers; otherwise discrepancies would be hidden.
select results.session_key, results.driver_key
from {{ ref('stg_f1__vb_results') }} as results
left join {{ ref('dim_session_crosswalk') }} as sessions on sessions.session_key = results.session_key
left join {{ ref('dim_driver_crosswalk') }} as drivers on drivers.driver_key = results.driver_key
where sessions.race_id is null or drivers.driver_id is null
