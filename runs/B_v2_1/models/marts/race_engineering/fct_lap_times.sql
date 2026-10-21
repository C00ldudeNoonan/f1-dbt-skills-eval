{#-
  One row per driver per lap per race.

  Incremental, processed a whole race at a time (delete+insert on race_id).
  Each run reloads:
    - every race in the source that isn't in this table yet, and
    - the N most recent races already in this table (var lap_correction_window_races),
      because the timing provider can reissue corrected laps for them.
  Replacing the whole race (not merging row by row) means a correction that
  removes or renumbers laps is also applied.
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
    select * from {{ ref('stg_ergast__lap_times') }}
),

races as (
    select * from {{ ref('stg_ergast__races') }}
),

{% if is_incremental() %}
loaded_races as (
    select distinct race_id, season, round from {{ this }}
),

races_to_load as (
    -- New races
    select distinct laps.race_id
    from laps
    left join loaded_races
        on laps.race_id = loaded_races.race_id
    where loaded_races.race_id is null

    union

    -- Most recent races already loaded, which may have been corrected
    select race_id
    from loaded_races
    qualify row_number() over (order by season desc, round desc)
        <= {{ var('lap_correction_window_races') }}
),
{% endif %}

final as (
    select
        laps.race_id,
        races.season,
        races.round,
        laps.driver_id,
        laps.lap,
        laps.position,
        laps.lap_time_ms,
        -- When this race was last (re)loaded. fct_stints uses it to find races to recompute.
        current_timestamp()::timestamp_ntz as loaded_at
    from laps
    inner join races
        on laps.race_id = races.race_id
    {% if is_incremental() %}
    where laps.race_id in (select race_id from races_to_load)
    {% endif %}
)

select * from final
