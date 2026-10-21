{#
    Every non-blank raw value must parse into its staging column. For each parsed field this
    counts the raw values that are present (not NULL, not blank, not the \N sentinel) and the
    staging values that are not NULL. A mismatch means the vendor changed a format and the
    parser is now dropping values silently. Any row returned fails the build.
#}
with checks as (
    select
        'results.milliseconds -> stg_f1__results.race_time_ms' as check_name,
        (select count(*) from {{ source('f1_raw', 'results') }} as src
            where src.milliseconds is not null and trim(src.milliseconds) not in ('', '\\N')) as source_values,
        (select count(*) from {{ ref('stg_f1__results') }} where race_time_ms is not null) as parsed_values
union all
    select
        'results.fastestlaptime -> stg_f1__results.fastest_lap_time_ms' as check_name,
        (select count(*) from {{ source('f1_raw', 'results') }} as src
            where src.fastestlaptime is not null and trim(src.fastestlaptime) not in ('', '\\N')) as source_values,
        (select count(*) from {{ ref('stg_f1__results') }} where fastest_lap_time_ms is not null) as parsed_values
union all
    select
        'results.position -> stg_f1__results.position' as check_name,
        (select count(*) from {{ source('f1_raw', 'results') }} as src
            where src.position is not null and trim(src.position) not in ('', '\\N')) as source_values,
        (select count(*) from {{ ref('stg_f1__results') }} where position is not null) as parsed_values
union all
    select
        'results.points -> stg_f1__results.points' as check_name,
        (select count(*) from {{ source('f1_raw', 'results') }} as src
            where src.points is not null and trim(src.points) not in ('', '\\N')) as source_values,
        (select count(*) from {{ ref('stg_f1__results') }} where points is not null) as parsed_values
union all
    select
        'results.position_order -> stg_f1__results.position_order' as check_name,
        (select count(*) from {{ source('f1_raw', 'results') }} as src
            where src.position_order is not null and trim(src.position_order) not in ('', '\\N')) as source_values,
        (select count(*) from {{ ref('stg_f1__results') }} where position_order is not null) as parsed_values
union all
    select
        'results.grid -> stg_f1__results.grid' as check_name,
        (select count(*) from {{ source('f1_raw', 'results') }} as src
            where src.grid is not null and trim(src.grid) not in ('', '\\N')) as source_values,
        (select count(*) from {{ ref('stg_f1__results') }} where grid is not null) as parsed_values
union all
    select
        'sprint_results.milliseconds -> stg_f1__sprint_results.race_time_ms' as check_name,
        (select count(*) from {{ source('f1_raw', 'sprint_results') }} as src
            where src.milliseconds is not null and trim(src.milliseconds) not in ('', '\\N')) as source_values,
        (select count(*) from {{ ref('stg_f1__sprint_results') }} where race_time_ms is not null) as parsed_values
union all
    select
        'sprint_results.position -> stg_f1__sprint_results.position' as check_name,
        (select count(*) from {{ source('f1_raw', 'sprint_results') }} as src
            where src.position is not null and trim(src.position) not in ('', '\\N')) as source_values,
        (select count(*) from {{ ref('stg_f1__sprint_results') }} where position is not null) as parsed_values
union all
    select
        'sprint_results.position_order -> stg_f1__sprint_results.position_order' as check_name,
        (select count(*) from {{ source('f1_raw', 'sprint_results') }} as src
            where src.position_order is not null and trim(src.position_order) not in ('', '\\N')) as source_values,
        (select count(*) from {{ ref('stg_f1__sprint_results') }} where position_order is not null) as parsed_values
union all
    select
        'lap_times.milliseconds -> stg_f1__lap_times.lap_ms' as check_name,
        (select count(*) from {{ source('f1_raw', 'lap_times') }} as src
            where src.milliseconds is not null and trim(src.milliseconds) not in ('', '\\N')) as source_values,
        (select count(*) from {{ ref('stg_f1__lap_times') }} where lap_ms is not null) as parsed_values
union all
    select
        'pit_stops.milliseconds -> stg_f1__pit_stops.pit_stop_ms' as check_name,
        (select count(*) from {{ source('f1_raw', 'pit_stops') }} as src
            where src.milliseconds is not null and trim(src.milliseconds) not in ('', '\\N')) as source_values,
        (select count(*) from {{ ref('stg_f1__pit_stops') }} where pit_stop_ms is not null) as parsed_values
union all
    select
        'qualifying.q1 -> stg_f1__qualifying.q1_ms' as check_name,
        (select count(*) from {{ source('f1_raw', 'qualifying') }} as src
            where src.q1 is not null and trim(src.q1) not in ('', '\\N')) as source_values,
        (select count(*) from {{ ref('stg_f1__qualifying') }} where q1_ms is not null) as parsed_values
union all
    select
        'qualifying.q2 -> stg_f1__qualifying.q2_ms' as check_name,
        (select count(*) from {{ source('f1_raw', 'qualifying') }} as src
            where src.q2 is not null and trim(src.q2) not in ('', '\\N')) as source_values,
        (select count(*) from {{ ref('stg_f1__qualifying') }} where q2_ms is not null) as parsed_values
union all
    select
        'qualifying.q3 -> stg_f1__qualifying.q3_ms' as check_name,
        (select count(*) from {{ source('f1_raw', 'qualifying') }} as src
            where src.q3 is not null and trim(src.q3) not in ('', '\\N')) as source_values,
        (select count(*) from {{ ref('stg_f1__qualifying') }} where q3_ms is not null) as parsed_values
union all
    select
        'races.date -> stg_f1__races.race_date' as check_name,
        (select count(*) from {{ source('f1_raw', 'races') }} as src
            where src.date is not null and trim(src.date) not in ('', '\\N')) as source_values,
        (select count(*) from {{ ref('stg_f1__races') }} where race_date is not null) as parsed_values
union all
    select
        'drivers.dob -> stg_f1__drivers.date_of_birth' as check_name,
        (select count(*) from {{ source('f1_raw', 'drivers') }} as src
            where src.dob is not null and trim(src.dob) not in ('', '\\N')) as source_values,
        (select count(*) from {{ ref('stg_f1__drivers') }} where date_of_birth is not null) as parsed_values
union all
    select
        'driver_standings.points -> stg_f1__driver_standings.points' as check_name,
        -- staging keeps one row per race and driver, so count source pairs, not raw rows
        (select count(*) from (
            select distinct src.raceid, src.driverid from {{ source('f1_raw', 'driver_standings') }} as src
            where src.points is not null and trim(src.points) not in ('', '\\N')
        )) as source_values,
        (select count(*) from {{ ref('stg_f1__driver_standings') }} where points is not null) as parsed_values
)

select *
from checks
where source_values <> parsed_values
