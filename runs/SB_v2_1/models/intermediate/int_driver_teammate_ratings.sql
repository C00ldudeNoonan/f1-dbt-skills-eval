-- A teammate comparison only says "A beat B". If B was a champion, A is better than the raw number suggests; if B was
-- weak, worse. This chains the comparisons across everyone who ever shared a car (drivers move teams, which links
-- the whole grid) and solves for one rating per driver such that  rating(A) - rating(B) ~ edge(A over B).
--
-- Method: ridge-regularised Jacobi iteration, unrolled in SQL (40 rounds converge well past two decimals):
--   rating_i  <-  sum_j n_ij * (edge_ij + rating_j) / (sum_j n_ij + lambda)
-- n_ij = qualifying comparisons, edge_ij = mean qualifying advantage of i over teammate j (percent of lap time),
-- lambda pseudo-comparisons pull thinly-evidenced drivers towards the grid average (0).
-- Ratings are in percent of lap time relative to the average driver in this connected graph; positive = faster.
{% set rounds = var('rating_iterations', 40) %}
{% set lambda_ = var('rating_ridge_lambda', 20) %}

with edges as (
    select driver_id, teammate_id, qualifying_comparisons as n, -mean_qual_delta_pct as edge
    from {{ ref('mart_driver_teammate_pairs') }}
    where qualifying_comparisons > 0
),

r0 as (
    select distinct driver_id, 0.0::float as rating from edges
)
{% for i in range(1, rounds + 1) %}
, r{{ i }} as (
    select
        e.driver_id,
        sum(e.n * (e.edge + t.rating)) / (sum(e.n) + {{ lambda_ }}) as rating
    from edges as e
    inner join r{{ i - 1 }} as t on t.driver_id = e.teammate_id
    group by e.driver_id
)
{% endfor %}

-- re-centred so the average rated driver is exactly 0
select driver_id, (rating - avg(rating) over ())::number(8, 4) as rating_pct
from r{{ rounds }}
