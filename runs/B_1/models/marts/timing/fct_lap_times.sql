{#
    One row per driver per lap per Grand Prix (lap timing exists from 1996).

    Incremental: each run reprocesses only
      * races not yet loaded, and
      * the N most recently loaded races (var lap_times_reprocess_recent_races,
        default 2), because the timing provider can reissue corrected lap
        times for them.
    delete+insert on race_id replaces a reprocessed race wholesale, so
    corrected times, added laps and withdrawn laps all flow through.
    "Most recent" is by (season, round): race_id is not chronological.
    A correction to an older race needs `--full-refresh`.
#}

{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='race_id',
        on_schema_change='append_new_columns',
        cluster_by=['season', 'round']
    )
}}

with lap_times as (
    select * from {{ ref('stg_ergast__lap_times') }}
),

races as (
    select race_id, season, round from {{ ref('stg_ergast__races') }}
),

{% if is_incremental() %}
recently_loaded_races as (
    select distinct season, round
    from {{ this }}
    order by season desc, round desc
    limit {{ var('lap_times_reprocess_recent_races') }}
),

reprocess_from as (
    -- Earliest of the N most recently loaded races. Null on an empty table, in
    -- which case everything is (re)loaded.
    select season, round
    from recently_loaded_races
    order by season, round
    limit 1
),
{% endif %}

races_to_process as (
    select races.race_id, races.season, races.round
    from races
    {% if is_incremental() %}
    left join reprocess_from on true
    where reprocess_from.season is null
       or races.season > reprocess_from.season
       or (races.season = reprocess_from.season and races.round >= reprocess_from.round)
    {% endif %}
)

select
    lap_times.race_id,
    races_to_process.season,
    races_to_process.round,
    lap_times.driver_id,
    lap_times.lap,
    lap_times.position,
    lap_times.lap_time_ms,
    lap_times.lap_time_text
from lap_times
inner join races_to_process
    on lap_times.race_id = races_to_process.race_id
