-- Guards against join fan-out / row loss between staging and fct_results (e.g. a duplicated
-- dimension row doubling a constructor's results): row count and total points must match.
with staged as (
    select count(*) as n_rows, sum(points) as total_points from {{ ref('stg_ergast__results') }}
),
fact as (
    select count(*) as n_rows, sum(points) as total_points from {{ ref('fct_results') }}
)
select staged.n_rows as staged_rows, fact.n_rows as fact_rows, staged.total_points as staged_points, fact.total_points as fact_points
from staged cross join fact
where staged.n_rows <> fact.n_rows or staged.total_points <> fact.total_points
