-- Join fan-out guard. Each fact must have exactly as many rows as the staged
-- rows it's built from. A duplicate dimension row (for example a second
-- Ferrari in constructors) multiplies every fact row that joins to it, and
-- this test fails on that before a dashboard sees doubled numbers.

with checks as (
    select
        'fct_results vs stg_f1__results' as check_name,
        (select count(*) from {{ ref('fct_results') }}) as actual_rows,
        (select count(*) from {{ ref('stg_f1__results') }}) as expected_rows
    union all
    select
        'fct_session_results vs GP + sprint results',
        (select count(*) from {{ ref('fct_session_results') }}),
        (select count(*) from {{ ref('stg_f1__results') }})
            + (select count(*) from {{ ref('stg_f1__sprint_results') }})
    union all
    select
        'fct_qualifying vs stg_f1__qualifying',
        (select count(*) from {{ ref('fct_qualifying') }}),
        (select count(*) from {{ ref('stg_f1__qualifying') }})
    union all
    select
        'mart_constructor_season_pit_stops stops vs staged stops <= 60s',
        (select sum(pit_stop_count) from {{ ref('mart_constructor_season_pit_stops') }}),
        (select count(*) from {{ ref('stg_f1__pit_stops') }} where duration_ms <= 60000)
    union all
    select
        'dim_drivers vs drivers + placeholders',
        (select count(*) from {{ ref('dim_drivers') }}),
        (select count(*) from {{ ref('stg_f1__drivers') }})
            + (select count(*) from {{ ref('mon_late_arriving_drivers') }})
    union all
    select
        'mart_driver_standings_by_round vs staged standings for completed rounds',
        (select count(*) from {{ ref('mart_driver_standings_by_round') }}),
        (select count(*)
         from {{ ref('stg_f1__driver_standings') }} as standings
         inner join {{ ref('int_f1__race_calendar') }} as calendar
             on standings.race_id = calendar.race_id
         where calendar.is_completed)
)

select *
from checks
where actual_rows is distinct from expected_rows
