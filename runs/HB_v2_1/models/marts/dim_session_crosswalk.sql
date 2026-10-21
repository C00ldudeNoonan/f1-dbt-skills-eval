{#
    One row per Vendor B session, mapped to our race_id and session_type ('race' or 'sprint').
    Matching rules are in int_vendor_b_session_match. Every row must have a race_id: the build
    fails if a Vendor B session cannot be matched.
#}
select
    session_key,
    race_id,
    session_type,
    match_method

from {{ ref('int_vendor_b_session_match') }}
