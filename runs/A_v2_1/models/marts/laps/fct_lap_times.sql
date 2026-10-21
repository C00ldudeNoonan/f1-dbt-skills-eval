{#-
    One row per driver per lap per race.

    Incremental, delete+insert by race. Each run reloads every lap of:
      * races in the source that the table does not have yet, and
      * the var('lap_correction_window_races') (2) most recent races already
        loaded, because the timing provider can reissue corrected lap times
        for those.
    Replacing whole races (rather than merging lap rows) also removes laps the
    provider withdraws in a correction.

    dbt_updated_at records when a race was last (re)loaded. fct_stints uses it
    to find the races it has to rebuild.
-#}
{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='race_id',
        on_schema_change='append_new_columns',
        cluster_by=['race_id']
    )
}}

with laps as (

    select * from {{ ref('stg_ergast__lap_times') }}

),

races as (

    select * from {{ ref('stg_ergast__races') }}

)

{% if is_incremental() %}
,

loaded_races as (

    select distinct race_id, race_date
    from {{ this }}

),

races_to_load as (

    -- New races.
    select distinct laps.race_id
    from laps
    where laps.race_id not in (select race_id from loaded_races)

    union

    -- Correction window: the most recent races already loaded.
    select race_id
    from loaded_races
    qualify row_number() over (order by race_date desc, race_id desc)
        <= {{ var('lap_correction_window_races') }}

)
{% endif %}

select
    laps.race_id,
    races.season,
    races.round,
    races.race_date,
    laps.driver_id,
    laps.lap,
    laps.position,
    laps.lap_time_ms,
    current_timestamp()::timestamp_ntz as dbt_updated_at
from laps
inner join races
    on laps.race_id = races.race_id
{% if is_incremental() %}
where laps.race_id in (select race_id from races_to_load)
{% endif %}
