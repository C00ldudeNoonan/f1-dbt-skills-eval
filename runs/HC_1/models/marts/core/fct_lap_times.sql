{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='race_id',
        on_schema_change='fail'
    )
}}

-- One row per driver per lap per Grand Prix.
--
-- Incremental strategy: the unit of replacement is the whole race (`unique_key='race_id'`).
-- The timing provider can reissue corrected lap times for the two most recent races already
-- loaded, and a correction can add or drop laps, so each run deletes and re-inserts every race
-- dated on or after the second most recent race in this table. Races before that are never
-- reprocessed. A full refresh rebuilds the whole history.
with lap_times as (

    select * from {{ ref('stg_ergast__lap_times') }}

),

races as (

    select * from {{ ref('stg_ergast__races') }}

)

select
    races.race_id,
    races.season,
    races.round,
    races.race_date,
    lap_times.driver_id,
    lap_times.lap,
    lap_times.position,
    lap_times.lap_time_ms
from lap_times
inner join races
    on lap_times.race_id = races.race_id

{% if is_incremental() %}
-- Second most recent race_date already loaded. Including it means the two most recent races
-- (and anything newer) are fully reprocessed.
where races.race_date >= (
    select min(race_date)
    from (
        select distinct race_date
        from {{ this }}
        order by race_date desc
        limit 2
    )
)
{% endif %}
