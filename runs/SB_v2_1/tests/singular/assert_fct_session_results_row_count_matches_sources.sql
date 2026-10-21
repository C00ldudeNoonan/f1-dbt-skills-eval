select expected.n as expected_rows, modelled.n as fct_rows
from (
    select (select count(*) from {{ ref('stg_f1__results') }}) + (select count(*) from {{ ref('stg_f1__sprint_results') }}) as n
) as expected
cross join (select count(*) as n from {{ ref('fct_session_results') }}) as modelled
where expected.n <> modelled.n
