{#
    fct_session_results must hold exactly one row per staged race result and per staged sprint result.
#}
with expected as (

    select
        (select count(*) from {{ ref('stg_f1__results') }}) as race_rows,
        (select count(*) from {{ ref('stg_f1__sprint_results') }}) as sprint_rows

),

actual as (

    select
        count_if(session_type = 'race') as race_rows,
        count_if(session_type = 'sprint') as sprint_rows
    from {{ ref('fct_session_results') }}

)

select
    expected.race_rows as expected_race_rows,
    actual.race_rows as actual_race_rows,
    expected.sprint_rows as expected_sprint_rows,
    actual.sprint_rows as actual_sprint_rows
from expected
cross join actual
where actual.race_rows <> expected.race_rows
    or actual.sprint_rows <> expected.sprint_rows
