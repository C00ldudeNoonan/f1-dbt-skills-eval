{{ config(materialized='view') }}

-- Live duplicate report for every raw table, by natural key. extra_rows are
-- rows beyond one per key (staging keeps one); conflicting_versions counts
-- extra versions of keys whose copies disagree after cleaning (trim, \N -> null), which fail the
-- raw_<table>__no_conflicting_duplicates source tests. Both are 0 on a healthy feed.
with per_table as (

    select
        'circuits' as table_name,
        'circuitid' as natural_key,
        count(*) as raw_rows,
        count(distinct hash(circuitid)) as distinct_keys,
        count(*) - count(distinct hash(circuitid)) as extra_rows,
        count(distinct hash(circuitid), {{ raw_row_hash(source('ergast', 'circuits'), []) }}) - count(distinct hash(circuitid)) as conflicting_versions
    from {{ source('ergast', 'circuits') }}

    union all

    select
        'constructors' as table_name,
        'constructorid' as natural_key,
        count(*) as raw_rows,
        count(distinct hash(constructorid)) as distinct_keys,
        count(*) - count(distinct hash(constructorid)) as extra_rows,
        count(distinct hash(constructorid), {{ raw_row_hash(source('ergast', 'constructors'), []) }}) - count(distinct hash(constructorid)) as conflicting_versions
    from {{ source('ergast', 'constructors') }}

    union all

    select
        'constructor_results' as table_name,
        'raceid, constructorid' as natural_key,
        count(*) as raw_rows,
        count(distinct hash(raceid, constructorid)) as distinct_keys,
        count(*) - count(distinct hash(raceid, constructorid)) as extra_rows,
        count(distinct hash(raceid, constructorid), {{ raw_row_hash(source('ergast', 'constructor_results'), ['constructorresultsid']) }}) - count(distinct hash(raceid, constructorid)) as conflicting_versions
    from {{ source('ergast', 'constructor_results') }}

    union all

    select
        'constructor_standings' as table_name,
        'raceid, constructorid' as natural_key,
        count(*) as raw_rows,
        count(distinct hash(raceid, constructorid)) as distinct_keys,
        count(*) - count(distinct hash(raceid, constructorid)) as extra_rows,
        count(distinct hash(raceid, constructorid), {{ raw_row_hash(source('ergast', 'constructor_standings'), ['constructorstandingsid']) }}) - count(distinct hash(raceid, constructorid)) as conflicting_versions
    from {{ source('ergast', 'constructor_standings') }}

    union all

    select
        'drivers' as table_name,
        'driverid' as natural_key,
        count(*) as raw_rows,
        count(distinct hash(driverid)) as distinct_keys,
        count(*) - count(distinct hash(driverid)) as extra_rows,
        count(distinct hash(driverid), {{ raw_row_hash(source('ergast', 'drivers'), []) }}) - count(distinct hash(driverid)) as conflicting_versions
    from {{ source('ergast', 'drivers') }}

    union all

    select
        'driver_standings' as table_name,
        'raceid, driverid' as natural_key,
        count(*) as raw_rows,
        count(distinct hash(raceid, driverid)) as distinct_keys,
        count(*) - count(distinct hash(raceid, driverid)) as extra_rows,
        count(distinct hash(raceid, driverid), {{ raw_row_hash(source('ergast', 'driver_standings'), ['driverstandingsid']) }}) - count(distinct hash(raceid, driverid)) as conflicting_versions
    from {{ source('ergast', 'driver_standings') }}

    union all

    select
        'lap_times' as table_name,
        'raceid, driverid, lap' as natural_key,
        count(*) as raw_rows,
        count(distinct hash(raceid, driverid, lap)) as distinct_keys,
        count(*) - count(distinct hash(raceid, driverid, lap)) as extra_rows,
        count(distinct hash(raceid, driverid, lap), {{ raw_row_hash(source('ergast', 'lap_times'), []) }}) - count(distinct hash(raceid, driverid, lap)) as conflicting_versions
    from {{ source('ergast', 'lap_times') }}

    union all

    select
        'pit_stops' as table_name,
        'raceid, driverid, stop' as natural_key,
        count(*) as raw_rows,
        count(distinct hash(raceid, driverid, stop)) as distinct_keys,
        count(*) - count(distinct hash(raceid, driverid, stop)) as extra_rows,
        count(distinct hash(raceid, driverid, stop), {{ raw_row_hash(source('ergast', 'pit_stops'), []) }}) - count(distinct hash(raceid, driverid, stop)) as conflicting_versions
    from {{ source('ergast', 'pit_stops') }}

    union all

    select
        'qualifying' as table_name,
        'raceid, driverid' as natural_key,
        count(*) as raw_rows,
        count(distinct hash(raceid, driverid)) as distinct_keys,
        count(*) - count(distinct hash(raceid, driverid)) as extra_rows,
        count(distinct hash(raceid, driverid), {{ raw_row_hash(source('ergast', 'qualifying'), ['qualifyid']) }}) - count(distinct hash(raceid, driverid)) as conflicting_versions
    from {{ source('ergast', 'qualifying') }}

    union all

    select
        'races' as table_name,
        'raceid' as natural_key,
        count(*) as raw_rows,
        count(distinct hash(raceid)) as distinct_keys,
        count(*) - count(distinct hash(raceid)) as extra_rows,
        count(distinct hash(raceid), {{ raw_row_hash(source('ergast', 'races'), []) }}) - count(distinct hash(raceid)) as conflicting_versions
    from {{ source('ergast', 'races') }}

    union all

    select
        'results' as table_name,
        'resultid' as natural_key,
        count(*) as raw_rows,
        count(distinct hash(resultid)) as distinct_keys,
        count(*) - count(distinct hash(resultid)) as extra_rows,
        count(distinct hash(resultid), {{ raw_row_hash(source('ergast', 'results'), []) }}) - count(distinct hash(resultid)) as conflicting_versions
    from {{ source('ergast', 'results') }}

    union all

    select
        'seasons' as table_name,
        'year' as natural_key,
        count(*) as raw_rows,
        count(distinct hash(year)) as distinct_keys,
        count(*) - count(distinct hash(year)) as extra_rows,
        count(distinct hash(year), {{ raw_row_hash(source('ergast', 'seasons'), []) }}) - count(distinct hash(year)) as conflicting_versions
    from {{ source('ergast', 'seasons') }}

    union all

    select
        'sprint_results' as table_name,
        'raceid, driverid' as natural_key,
        count(*) as raw_rows,
        count(distinct hash(raceid, driverid)) as distinct_keys,
        count(*) - count(distinct hash(raceid, driverid)) as extra_rows,
        count(distinct hash(raceid, driverid), {{ raw_row_hash(source('ergast', 'sprint_results'), ['resultid']) }}) - count(distinct hash(raceid, driverid)) as conflicting_versions
    from {{ source('ergast', 'sprint_results') }}

    union all

    select
        'status' as table_name,
        'statusid' as natural_key,
        count(*) as raw_rows,
        count(distinct hash(statusid)) as distinct_keys,
        count(*) - count(distinct hash(statusid)) as extra_rows,
        count(distinct hash(statusid), {{ raw_row_hash(source('ergast', 'status'), []) }}) - count(distinct hash(statusid)) as conflicting_versions
    from {{ source('ergast', 'status') }}

)

select * from per_table
