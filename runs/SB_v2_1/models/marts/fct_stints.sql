-- Grain: one row per driver per stint, for races that have pit stop data.
-- A pit stop on lap L ends the stint at L; the next starts at L + 1. The last stint ends on the
-- driver's last recorded lap; stints with no laps (e.g. a stop on the final lap) are dropped.
-- Incremental by race: reprocesses races not yet loaded here plus the two latest races in
-- this table (where corrections can land), replacing them wholesale.
{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='race_id',
        on_schema_change='fail'
    )
}}

with pit_races as (
    select distinct race_id from {{ ref('stg_f1__pit_stops') }}
),

lap_races as (
    select distinct race_id, season * 100 + round as race_seq
    from {{ ref('fct_lap_times') }}
),

target_races as (
    select lap_races.race_id
    from lap_races
    inner join pit_races on pit_races.race_id = lap_races.race_id
    {% if is_incremental() %}
    where lap_races.race_id not in (select race_id from {{ this }})
       or lap_races.race_seq >= (
            -- same window as fct_lap_times, taken from this table's own latest two races. Its loaded
            -- races lag or equal the lap table's, so the window always covers every race the lap
            -- table just rewrote (a new race plus the two before it).
            select min(race_seq) from (
                select lap_races.race_seq
                from lap_races
                where lap_races.race_id in (select race_id from {{ this }})
                qualify row_number() over (order by lap_races.race_seq desc) <= 2
            )
       )
    {% endif %}
),

laps as (
    select fct_lap_times.*
    from {{ ref('fct_lap_times') }} as fct_lap_times
    inner join target_races on target_races.race_id = fct_lap_times.race_id
),

driver_races as (
    select race_id, driver_id, max(lap) as last_lap from laps group by 1, 2
),

stint_starts as (
    select race_id, driver_id, 1 as start_lap from driver_races
    union
    select pit_stops.race_id, pit_stops.driver_id, pit_stops.lap + 1
    from {{ ref('stg_f1__pit_stops') }} as pit_stops
    inner join target_races on target_races.race_id = pit_stops.race_id
),

stint_bounds as (
    select
        stint_starts.race_id,
        stint_starts.driver_id,
        stint_starts.start_lap,
        coalesce(
            lead(stint_starts.start_lap) over (
                partition by stint_starts.race_id, stint_starts.driver_id order by stint_starts.start_lap
            ) - 1,
            driver_races.last_lap
        ) as end_lap
    from stint_starts
    inner join driver_races
        on driver_races.race_id = stint_starts.race_id
        and driver_races.driver_id = stint_starts.driver_id
),

stints as (
    select
        stint_bounds.race_id,
        stint_bounds.driver_id,
        stint_bounds.start_lap,
        stint_bounds.end_lap,
        count(*)::integer as stint_laps,
        avg(laps.lap_time_ms)::number(14, 3) as avg_lap_time_ms
    from stint_bounds
    inner join laps
        on laps.race_id = stint_bounds.race_id
        and laps.driver_id = stint_bounds.driver_id
        and laps.lap between stint_bounds.start_lap and stint_bounds.end_lap
    group by 1, 2, 3, 4
)

select
    race_id,
    driver_id,
    row_number() over (partition by race_id, driver_id order by start_lap)::integer as stint_number,
    start_lap,
    end_lap,
    stint_laps,
    avg_lap_time_ms
from stints
