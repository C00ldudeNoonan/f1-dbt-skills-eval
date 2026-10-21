{#
    Two Vendor B sessions must not match the same race and session type. That would mean one of them is
    matched to the wrong session.
#}
select
    race_id,
    session_type,
    count(*) as vendor_b_sessions
from {{ ref('dim_session_crosswalk') }}
where race_id is not null
group by race_id, session_type
having count(*) > 1
