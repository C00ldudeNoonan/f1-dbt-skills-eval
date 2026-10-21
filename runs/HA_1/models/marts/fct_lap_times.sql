-- One row per driver per lap per race.
--
-- Incremental, keyed by race_id with delete+insert. A run rebuilds:
--   1. every race not yet in the table (new Grands Prix), and
--   2. the two most recent races already loaded, because the timing provider
--      sometimes reissues corrected lap times for them.
-- Each rebuilt race is replaced in full, so dropped or changed laps are also picked up.
-- Corrections to older races are not picked up by an incremental run. Use --full-refresh for those.

{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='race_id',
    on_schema_change='fail'
) }}

with lap_times as (

    select * from {{ ref('stg_f1__lap_times') }}

),

races as (

    select * from {{ ref('stg_f1__races') }}

),

{% if is_incremental() %}

recent_loaded_races as (

    select race_id
    from (
        select
            races.race_id,
            row_number() over (order by races.race_date desc) as recency_rank
        from races
        where races.race_id in (select distinct race_id from lap_times)
    )
    where recency_rank <= 2

),

{% endif %}

laps_to_load as (

    select lap_times.*
    from lap_times
    {% if is_incremental() %}
    where lap_times.race_id in (select race_id from recent_loaded_races)
        or lap_times.race_id not in (select race_id from {{ this }})
    {% endif %}

)

select
    laps_to_load.race_id,
    races.season,
    races.round,
    races.race_date,
    laps_to_load.driver_id,
    laps_to_load.lap_number as lap,
    laps_to_load.position,
    laps_to_load.lap_time_ms
from laps_to_load
inner join races
    on laps_to_load.race_id = races.race_id
