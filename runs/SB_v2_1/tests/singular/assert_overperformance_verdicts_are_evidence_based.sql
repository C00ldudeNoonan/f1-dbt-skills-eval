-- Only eligible drivers can be called overperformers/underperformers, and an overperformer must have a positive,
-- clearly non-zero edge. Ranks exist only for eligible drivers and are unique-ordered by the shrunk edge.
select driver_id
from {{ ref('mart_driver_overperformance') }}
where (verdict in ('overperforms', 'underperforms') and (edge_pct_shrunk is null or se_pct is null))
   or (verdict = 'overperforms' and (edge_pct <= 2 * se_pct or edge_pct_shrunk <= 0))
   or (verdict = 'underperforms' and (edge_pct >= -2 * se_pct or edge_pct_shrunk >= 0))
   or (verdict = 'insufficient_data' and rank_among_eligible is not null)
