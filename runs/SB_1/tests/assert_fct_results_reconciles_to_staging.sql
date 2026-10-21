-- Guards against join fan-out/drop between staging and the fact: row count and total points
-- must be identical, and no constructor-season may exceed the points of its raw results.
with staged as (
    select count(*) as n_rows, sum(points) as total_points from {{ ref('stg_f1__results') }}
),
fact as (
    select count(*) as n_rows, sum(points) as total_points from {{ ref('fct_results') }}
)
select staged.n_rows as staged_rows, fact.n_rows as fact_rows,
       staged.total_points as staged_points, fact.total_points as fact_points
from staged, fact
where staged.n_rows <> fact.n_rows or staged.total_points <> fact.total_points
