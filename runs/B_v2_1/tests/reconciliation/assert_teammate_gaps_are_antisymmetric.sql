-- If A out-qualified B in a session comparison, B must have lost to A in the
-- mirrored row: the two orderings must have opposite signs (or both be 0).
select a.race_id, a.driver_id, a.teammate_id, a.gap_pct, b.gap_pct as mirrored_gap_pct
from {{ ref('int_teammate_qualifying_gaps') }} as a
inner join {{ ref('int_teammate_qualifying_gaps') }} as b
    on a.race_id = b.race_id
    and a.constructor_id = b.constructor_id
    and a.driver_id = b.teammate_id
    and a.teammate_id = b.driver_id
where sign(a.gap_pct) <> -sign(b.gap_pct)
    or a.session_compared <> b.session_compared
