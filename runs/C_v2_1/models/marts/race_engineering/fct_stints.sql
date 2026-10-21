{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='race_id',
        on_schema_change='fail'
    )
}}

-- Tyre stints for races with pit stop data. Stint 1 starts on lap 1; a pit
-- stop on lap L ends the stint at lap L and the next one starts at L + 1. The
-- final stint ends on the driver's last recorded lap, and stints with no laps
-- (a stop on the last lap) are dropped.
--
-- Incremental by whole race. A race is rebuilt when fct_lap_times has
-- (re)loaded its laps since this table last built it (tracked through
-- laps_loaded_at), or when it has pit stop data but no stints yet. That keeps
-- stints in step with lap corrections without a full refresh.

with lap_times as (
    select * from {{ ref('fct_lap_times') }}
),

pit_stops as (
    select * from {{ ref('stg_f1__pit_stops') }}
),

pit_stop_races as (
    select distinct race_id
    from pit_stops
),

race_lap_loads as (
    select
        lap_times.race_id,
        max(lap_times.loaded_at) as laps_loaded_at
    from lap_times
    inner join pit_stop_races
        on lap_times.race_id = pit_stop_races.race_id
    group by lap_times.race_id
),

{% if is_incremental() %}

built_races as (
    select
        race_id,
        max(laps_loaded_at) as laps_loaded_at
    from {{ this }}
    group by race_id
),

{% endif %}

races_to_build as (
    select
        race_lap_loads.race_id,
        race_lap_loads.laps_loaded_at
    from race_lap_loads
    {% if is_incremental() %}
    left join built_races
        on race_lap_loads.race_id = built_races.race_id
    where built_races.race_id is null
        or race_lap_loads.laps_loaded_at > built_races.laps_loaded_at
    {% endif %}
),

pit_laps as (
    -- Distinct laps, so two stops logged on the same lap make one boundary.
    select distinct
        pit_stops.race_id,
        pit_stops.driver_id,
        pit_stops.lap as pit_lap
    from pit_stops
    inner join races_to_build
        on pit_stops.race_id = races_to_build.race_id
),

laps_with_stint as (
    -- A lap's stint is 1 + the number of pit stops on earlier laps.
    select
        lap_times.race_id,
        lap_times.driver_id,
        lap_times.lap,
        lap_times.lap_time_ms,
        races_to_build.laps_loaded_at,
        (1 + count(pit_laps.pit_lap))::integer as stint_number
    from lap_times
    inner join races_to_build
        on lap_times.race_id = races_to_build.race_id
    left join pit_laps
        on lap_times.race_id = pit_laps.race_id
        and lap_times.driver_id = pit_laps.driver_id
        and pit_laps.pit_lap < lap_times.lap
    group by
        lap_times.race_id,
        lap_times.driver_id,
        lap_times.lap,
        lap_times.lap_time_ms,
        races_to_build.laps_loaded_at
)

select
    race_id,
    driver_id,
    stint_number,
    min(lap) as start_lap,
    max(lap) as end_lap,
    count(*)::integer as stint_laps,
    avg(lap_time_ms)::number(14, 3) as avg_lap_time_ms,
    max(laps_loaded_at) as laps_loaded_at
from laps_with_stint
group by race_id, driver_id, stint_number
