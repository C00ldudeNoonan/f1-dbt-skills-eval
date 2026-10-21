-- Every source result must appear exactly once in fct_session_results. Returns a row when counts differ.
with expected as (

    select
        (select count(*) from {{ ref('stg_ergast__results') }})
        + (select count(*) from {{ ref('stg_ergast__sprint_results') }}) as source_rows

),

actual as (

    select count(*) as session_rows from {{ ref('fct_session_results') }}

)

select
    expected.source_rows,
    actual.session_rows
from expected
cross join actual
where expected.source_rows <> actual.session_rows
