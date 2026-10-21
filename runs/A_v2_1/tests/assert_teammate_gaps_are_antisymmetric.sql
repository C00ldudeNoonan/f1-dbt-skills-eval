-- Same-car gaps are stored in both orderings; each pair must be exact
-- opposites (gap(a, b) = -gap(b, a)), or the network rating would be biased.
select a.race_id, a.driver_id, a.teammate_id, a.gap_pct, b.gap_pct as reverse_gap_pct
from {{ ref('int_teammate_qualifying_gaps') }} as a
inner join {{ ref('int_teammate_qualifying_gaps') }} as b
    on a.race_id = b.race_id
    and a.driver_id = b.teammate_id
    and a.teammate_id = b.driver_id
where abs(a.gap_pct + b.gap_pct) > 1e-9
   or a.session_compared != b.session_compared
