{#
  One row per driver per lap per race.

  Incremental, reprocessing whole races (delete+insert on race_id):
    - every race not yet in this table is loaded (new Grands Prix, and any
      late-arriving/backfilled race), and
    - the two most recent races already loaded are always re-read, because the
      timing provider can reissue corrected lap times for them. Replacing the
      whole race (rather than merging row by row) also removes laps the
      provider retracts.
  Older history is never re-read. "Most recent" is by race date — Ergast
  race_ids are NOT chronological.

  Run with --full-refresh to rebuild from scratch (e.g. if a correction ever
  lands for a race older than the two most recent).
#}

{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='race_id',
        on_schema_change='append_new_columns'
    )
}}

with lap_times as (
    select * from {{ ref('stg_ergast__lap_times') }}
),

races as (
    select race_id, season, round, race_date from {{ ref('stg_ergast__races') }}
),

results as (
    select race_id, driver_id, constructor_id from {{ ref('stg_ergast__results') }}
    -- shared drives (two result rows per driver) predate lap data; keep the join 1:1 regardless
    qualify row_number() over (partition by race_id, driver_id order by result_id) = 1
)

{% if is_incremental() %}
,

loaded_races as (
    select distinct race_id, race_date from {{ this }}
),

correction_window as (
    -- race date of the second most recent race already loaded
    select min(race_date) as window_start
    from (select race_date from loaded_races order by race_date desc limit 2)
),

races_to_process as (
    select races.race_id
    from races
    cross join correction_window
    where races.race_date >= correction_window.window_start
       or races.race_id not in (select race_id from loaded_races)
)
{% endif %}

select
    lap_times.race_id,
    races.season,
    races.round,
    races.race_date,
    lap_times.driver_id,
    results.constructor_id,
    lap_times.lap,
    lap_times.position,
    lap_times.lap_time_ms,
    current_timestamp()             as _loaded_at
from lap_times
inner join races
    on lap_times.race_id = races.race_id
left join results
    on lap_times.race_id = results.race_id
   and lap_times.driver_id = results.driver_id
{% if is_incremental() %}
where lap_times.race_id in (select race_id from races_to_process)
{% endif %}
