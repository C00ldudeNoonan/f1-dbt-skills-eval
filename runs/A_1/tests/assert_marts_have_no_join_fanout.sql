-- Join fan-out guard. A duplicated key in a lookup table (e.g. a second
-- constructors row for Ferrari, 2026-10) silently multiplies fact rows and
-- inflates every total for that entity, while grain tests on aggregated marts
-- can still pass (the duplicates land in the same group). Each check compares
-- a mart's row count / total with the staging model it is built from; any
-- returned row is a fan-out (or a lost row).

with checks as (

    select
        'fct_results rows vs stg results' as check_name,
        (select count(*) from {{ ref('fct_results') }}) as mart_value,
        (select count(*) from {{ ref('stg_ergast__results') }}) as expected_value

    union all

    select
        'fct_results points vs stg results',
        (select sum(points) from {{ ref('fct_results') }}),
        (select sum(points) from {{ ref('stg_ergast__results') }})

    union all

    select
        'fct_session_results rows vs stg results + sprints',
        (select count(*) from {{ ref('fct_session_results') }}),
        (select count(*) from {{ ref('stg_ergast__results') }})
          + (select count(*) from {{ ref('stg_ergast__sprint_results') }})

    union all

    select
        'pit stop mart stop count vs representative stops',
        (select sum(pit_stop_count) from {{ ref('mart_constructor_season_pit_stops') }}),
        (select count(*) from {{ ref('stg_ergast__pit_stops') }} where duration_ms <= 60000)

    union all

    select
        'fct_lap_times rows vs stg lap times',
        (select count(*) from {{ ref('fct_lap_times') }}),
        (select count(*) from {{ ref('stg_ergast__lap_times') }})

    union all

    select
        'dim_drivers rows vs stg drivers',
        (select count(*) from {{ ref('dim_drivers') }}),
        (select count(*) from {{ ref('stg_ergast__drivers') }})

)

select *
from checks
where not equal_null(mart_value, expected_value)
