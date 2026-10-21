-- Joins in the marts must neither drop nor fan out rows. Compare row counts (and, for
-- results, total points) between each fact/mart and the staging model it is built from.
with checks as (

    select 'fct_results rows' as check_name,
        (select count(*) from {{ ref('fct_results') }}) as actual,
        (select count(*) from {{ ref('stg_f1__results') }}) as expected
    union all
    select 'fct_results points',
        (select sum(points) from {{ ref('fct_results') }}),
        (select sum(points) from {{ ref('stg_f1__results') }})
    union all
    select 'fct_results wins',
        (select count_if(is_win) from {{ ref('fct_results') }}),
        (select count_if(finish_position = 1) from {{ ref('stg_f1__results') }})
    union all
    select 'fct_qualifying rows',
        (select count(*) from {{ ref('fct_qualifying') }}),
        (select count(*) from {{ ref('stg_f1__qualifying') }})
    union all
    select 'fct_session_results rows',
        (select count(*) from {{ ref('fct_session_results') }}),
        (select count(*) from {{ ref('stg_f1__results') }}) + (select count(*) from {{ ref('stg_f1__sprint_results') }})
    union all
    select 'standings by round rows',
        (select count(*) from {{ ref('mart_driver_standings_by_round') }}),
        (select count(*) from {{ ref('stg_f1__driver_standings') }})
    union all
    select 'dim_drivers rows',
        (select count(*) from {{ ref('dim_drivers') }}),
        (select count(*) from {{ ref('int_f1__drivers_with_placeholders') }})
    union all
    select 'fct_lap_times rows',
        (select count(*) from {{ ref('fct_lap_times') }}),
        (select count(*) from {{ ref('stg_f1__lap_times') }})

)

select * from checks where actual is distinct from expected
