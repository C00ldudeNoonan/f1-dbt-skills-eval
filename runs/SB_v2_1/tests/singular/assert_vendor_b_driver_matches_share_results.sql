-- Guards against a plausible-but-wrong driver match: a matched pair must appear together in at least one
-- mapped session of our feed (a driver we matched must actually have raced in a session Vendor B has them in).
select drivers.driver_key, drivers.driver_id
from {{ ref('dim_driver_crosswalk') }} as drivers
where not exists (
    select 1
    from {{ ref('stg_f1__vb_results') }} as results
    inner join {{ ref('dim_session_crosswalk') }} as sessions on sessions.session_key = results.session_key
    inner join {{ ref('fct_session_results') }} as ours
        on ours.race_id = sessions.race_id
        and ours.session_type = sessions.session_type
        and ours.driver_id = drivers.driver_id
    where results.driver_key = drivers.driver_key
)
