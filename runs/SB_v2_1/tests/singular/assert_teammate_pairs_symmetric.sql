-- If A was x% faster than B, B was x% slower than A: pair rows must mirror each other.
select a.driver_id, a.teammate_id, a.mean_qual_delta_pct, b.mean_qual_delta_pct as mirrored
from {{ ref('mart_driver_teammate_pairs') }} as a
left join {{ ref('mart_driver_teammate_pairs') }} as b
    on a.driver_id = b.teammate_id and a.teammate_id = b.driver_id
where b.driver_id is null
   or a.qualifying_comparisons <> b.qualifying_comparisons
   or abs(coalesce(a.mean_qual_delta_pct, 0) + coalesce(b.mean_qual_delta_pct, 0)) > 0.005
