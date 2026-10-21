{{ config(store_failures=true) }}

-- fct_results must have exactly the rows and points of stg_ergast__results for
-- every constructor. A duplicate row in any lookup joined in (constructors,
-- races, status) fans out results, which shows up here as that team's rows
-- and points multiplying while every other team looks fine.
with expected as (
    select constructor_id, count(*) as n_rows, sum(points) as points
    from {{ ref('stg_ergast__results') }}
    group by constructor_id
),

actual as (
    select constructor_id, count(*) as n_rows, sum(points) as points
    from {{ ref('fct_results') }}
    group by constructor_id
)

select
    coalesce(expected.constructor_id, actual.constructor_id) as constructor_id,
    expected.n_rows as expected_rows,
    actual.n_rows as actual_rows,
    expected.points as expected_points,
    actual.points as actual_points
from expected
full outer join actual
    on expected.constructor_id = actual.constructor_id
where expected.n_rows is distinct from actual.n_rows
   or expected.points is distinct from actual.points
