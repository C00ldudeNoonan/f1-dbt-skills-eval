{#-
  One row per driver per stint, for races that have pit stop data.

  Stint 1 starts on lap 1. A pit stop on lap L ends the current stint at lap L
  and the next stint starts at lap L + 1. The final stint ends on the driver's
  last recorded lap. Stints with no recorded laps are dropped.

  Incremental, a whole race at a time (delete+insert on race_id). A race is
  recomputed when:
    - it isn't in this table yet (new race, or its pit stop data arrived late),
    - fct_lap_times reloaded it since we last computed it (new or corrected laps), or
    - it is one of the N most recent races (picks up corrected pit stops).
-#}
{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='race_id',
        on_schema_change='fail'
    )
}}

with laps as (
    select * from {{ ref('fct_lap_times') }}
),

pit_laps as (
    -- Two stops on the same lap end a single stint.
    select distinct race_id, driver_id, lap
    from {{ ref('stg_ergast__pit_stops') }}
),

races_with_pit_data as (
    select
        laps.race_id,
        max(laps.season)    as season,
        max(laps.round)     as round,
        max(laps.loaded_at) as laps_loaded_at
    from laps
    where laps.race_id in (select race_id from pit_laps)
    group by laps.race_id
),

{% if is_incremental() %}
built_races as (
    select race_id, max(laps_loaded_at) as laps_loaded_at
    from {{ this }}
    group by race_id
),

recent_races as (
    select race_id
    from races_with_pit_data
    qualify row_number() over (order by season desc, round desc)
        <= {{ var('lap_correction_window_races') }}
),
{% endif %}

races_to_build as (
    select races_with_pit_data.race_id, races_with_pit_data.laps_loaded_at
    from races_with_pit_data
    {% if is_incremental() %}
    left join built_races
        on races_with_pit_data.race_id = built_races.race_id
    left join recent_races
        on races_with_pit_data.race_id = recent_races.race_id
    where built_races.race_id is null
        or races_with_pit_data.laps_loaded_at > built_races.laps_loaded_at
        or recent_races.race_id is not null
    {% endif %}
),

driver_laps as (
    select laps.race_id, laps.driver_id, laps.lap, laps.lap_time_ms
    from laps
    inner join races_to_build
        on laps.race_id = races_to_build.race_id
),

driver_last_lap as (
    select race_id, driver_id, max(lap) as last_lap
    from driver_laps
    group by race_id, driver_id
),

-- Stint k ends at the k-th pit lap; the final stint ends at the last recorded lap.
stint_ends as (
    select
        pit_laps.race_id,
        pit_laps.driver_id,
        pit_laps.lap as end_lap
    from pit_laps
    inner join driver_last_lap
        on pit_laps.race_id = driver_last_lap.race_id
        and pit_laps.driver_id = driver_last_lap.driver_id

    union all

    select race_id, driver_id, last_lap as end_lap
    from driver_last_lap
    -- A pit stop on the last lap already closes the final stint.
    where not exists (
        select 1 from pit_laps
        where pit_laps.race_id = driver_last_lap.race_id
            and pit_laps.driver_id = driver_last_lap.driver_id
            and pit_laps.lap = driver_last_lap.last_lap
    )
),

stint_bounds as (
    select
        race_id,
        driver_id,
        row_number() over (partition by race_id, driver_id order by end_lap)                as stint_number,
        coalesce(lag(end_lap) over (partition by race_id, driver_id order by end_lap), 0) + 1 as start_lap,
        end_lap
    from stint_ends
),

stints as (
    select
        stint_bounds.race_id,
        stint_bounds.driver_id,
        stint_bounds.stint_number,
        stint_bounds.start_lap,
        stint_bounds.end_lap,
        count(driver_laps.lap)                              as stint_laps,
        avg(driver_laps.lap_time_ms)::number(12, 3)         as avg_lap_time_ms
    from stint_bounds
    inner join driver_laps
        on stint_bounds.race_id = driver_laps.race_id
        and stint_bounds.driver_id = driver_laps.driver_id
        and driver_laps.lap between stint_bounds.start_lap and stint_bounds.end_lap
    group by 1, 2, 3, 4, 5
)

select
    stints.*,
    races_to_build.laps_loaded_at
from stints
inner join races_to_build
    on stints.race_id = races_to_build.race_id
