{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='race_id',
        on_schema_change='fail'
    )
}}

-- Incremental by whole race. Each run loads races not yet in the table and
-- reloads the two most recent races already loaded, because the timing
-- provider can reissue corrected lap times for those. delete+insert on
-- race_id replaces every lap of a reloaded race, so corrected, added and
-- withdrawn laps are all handled.

with lap_times as (
    select * from {{ ref('stg_f1__lap_times') }}
),

races as (
    select * from {{ ref('stg_f1__races') }}
),

{% if is_incremental() %}

loaded_races as (
    select
        race_id,
        season,
        round
    from {{ this }}
    group by race_id, season, round
),

recent_loaded_races as (
    select race_id
    from loaded_races
    order by season desc, round desc
    limit {{ var('lap_times_correction_window_races', 2) }}
),

new_races as (
    select distinct lap_times.race_id
    from lap_times
    left join loaded_races
        on lap_times.race_id = loaded_races.race_id
    where loaded_races.race_id is null
),

races_to_load as (
    select race_id from new_races
    union
    select race_id from recent_loaded_races
),

{% endif %}

final as (
    select
        lap_times.race_id,
        races.season,
        races.round,
        lap_times.driver_id,
        lap_times.lap,
        lap_times.position,
        lap_times.lap_time_ms,
        sysdate() as loaded_at
    from lap_times
    inner join races
        on lap_times.race_id = races.race_id
    {% if is_incremental() %}
    inner join races_to_load
        on lap_times.race_id = races_to_load.race_id
    {% endif %}
)

select * from final
