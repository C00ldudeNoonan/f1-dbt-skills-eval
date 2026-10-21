{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='race_id'
    )
}}

-- One row per driver per stint, for races that have pit stop data. A stop on lap L ends
-- the stint on lap L; the next stint starts on L+1. Each lap belongs to stint
-- 1 + (number of distinct stop laps before it), so stints with no laps (e.g. a stop on
-- the driver's final lap) never appear. Built from fct_lap_times, and incremental by race
-- with the same window: races not yet present plus the two most recent already loaded.
with laps as (

    select race_id, season, round, race_date, driver_id, lap, lap_time_ms
    from {{ ref('fct_lap_times') }}
    where race_id in (select race_id from {{ ref('stg_ergast__pit_stops') }})

    {% if is_incremental() %}
    and (
        race_id not in (select race_id from {{ this }})
        or race_date >= (
            select min(race_date)
            from (
                select distinct race_date
                from {{ this }}
                order by race_date desc
                limit 2
            )
        )
    )
    {% endif %}

),

stop_laps as (

    select distinct race_id, driver_id, lap as stop_lap
    from {{ ref('stg_ergast__pit_stops') }}

),

lap_stints as (

    select
        laps.race_id,
        laps.season,
        laps.round,
        laps.race_date,
        laps.driver_id,
        laps.lap,
        laps.lap_time_ms,
        1 + count(stop_laps.stop_lap) as stint_number
    from laps
    left join stop_laps
        on laps.race_id = stop_laps.race_id
        and laps.driver_id = stop_laps.driver_id
        and stop_laps.stop_lap < laps.lap
    group by laps.race_id, laps.season, laps.round, laps.race_date, laps.driver_id, laps.lap, laps.lap_time_ms

)

select
    race_id,
    season,
    round,
    race_date,
    driver_id,
    stint_number,
    min(lap) as start_lap,
    max(lap) as end_lap,
    count(*) as stint_laps,
    avg(lap_time_ms) as avg_lap_time_ms
from lap_stints
group by race_id, season, round, race_date, driver_id, stint_number
