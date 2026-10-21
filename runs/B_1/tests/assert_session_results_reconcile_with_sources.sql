-- fct_session_results must contain exactly the Grand Prix rows of fct_results
-- and the rows of stg_ergast__sprint_results, with the same points.
with expected as (
    select 'race' as session_type, count(*) as n_rows, sum(points) as points
    from {{ ref('fct_results') }}
    union all
    select 'sprint', count(*), sum(points)
    from {{ ref('stg_ergast__sprint_results') }}
),

actual as (
    select session_type, count(*) as n_rows, sum(points) as points
    from {{ ref('fct_session_results') }}
    group by session_type
)

select expected.session_type, expected.n_rows, actual.n_rows as actual_rows,
       expected.points, actual.points as actual_points
from expected
full outer join actual
    on expected.session_type = actual.session_type
where expected.n_rows is distinct from actual.n_rows
   or expected.points is distinct from actual.points
