{#
    One row per driver per stint, for races that have pit stop data.

    Stint 1 starts on lap 1. A pit stop on lap L ends the current stint at lap L, and
    the next stint starts on lap L+1. The final stint ends on the driver's last
    recorded lap. Stints with no laps are dropped. avg_lap_time_ms averages every
    lap in the stint, including lap 1 and pit laps.

    Incremental with the same window as fct_lap_times: races dated on or after the
    second most recent race already loaded are rebuilt, keyed on race_id.
#}
{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='race_id',
    on_schema_change='fail'
) }}

with pit_races as (

    select distinct race_id
    from {{ ref('stg_f1__pit_stops') }}

),

laps as (

    select fct_lap_times.*
    from {{ ref('fct_lap_times') }} as fct_lap_times
    inner join pit_races
        on fct_lap_times.race_id = pit_races.race_id

    {% if is_incremental() %}
    where fct_lap_times.race_date >= coalesce(
        (
            select min(recent.race_date)
            from (
                select race_date
                from {{ this }}
                group by race_date
                order by race_date desc
                limit 2
            ) as recent
        ),
        '1900-01-01'::date
    )
    {% endif %}

),

races_in_scope as (

    select distinct race_id
    from laps

),

pit_laps as (

    select distinct
        pit_stops.race_id,
        pit_stops.driver_id,
        pit_stops.lap_number

    from {{ ref('stg_f1__pit_stops') }} as pit_stops
    inner join races_in_scope
        on pit_stops.race_id = races_in_scope.race_id
    where pit_stops.lap_number is not null

),

driver_laps as (

    select
        race_id,
        driver_id,
        max(lap) as last_lap

    from laps
    group by race_id, driver_id

),

stint_starts as (

    select race_id, driver_id, 1 as start_lap
    from driver_laps

    union all

    select race_id, driver_id, lap_number + 1 as start_lap
    from pit_laps

),

stints as (

    select
        stint_starts.race_id,
        stint_starts.driver_id,
        row_number() over (
            partition by stint_starts.race_id, stint_starts.driver_id
            order by stint_starts.start_lap
        ) as stint_number,
        stint_starts.start_lap,
        coalesce(
            lead(stint_starts.start_lap) over (
                partition by stint_starts.race_id, stint_starts.driver_id
                order by stint_starts.start_lap
            ) - 1,
            driver_laps.last_lap
        ) as end_lap

    from stint_starts
    inner join driver_laps
        on stint_starts.race_id = driver_laps.race_id
        and stint_starts.driver_id = driver_laps.driver_id

)

select
    stints.race_id,
    max(laps.season) as season,
    max(laps.round) as round,
    max(laps.race_date) as race_date,
    stints.driver_id,
    stints.stint_number,
    stints.start_lap,
    stints.end_lap,
    count(*) as stint_laps,
    avg(laps.lap_time_ms) as avg_lap_time_ms

from stints
inner join laps
    on stints.race_id = laps.race_id
    and stints.driver_id = laps.driver_id
    and laps.lap between stints.start_lap and stints.end_lap
group by
    stints.race_id,
    stints.driver_id,
    stints.stint_number,
    stints.start_lap,
    stints.end_lap
