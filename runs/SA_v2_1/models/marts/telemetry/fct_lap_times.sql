{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='race_id'
    )
}}

-- One row per driver per lap per race. Incremental by race: each run reloads every race
-- that is not yet in the table, plus the two most recent races already loaded, because
-- the timing provider can reissue corrected lap times for those. Replacing whole races
-- (delete+insert on race_id) also drops laps that a correction removed.
with laps as (

    select * from {{ ref('stg_ergast__lap_times') }}

),

races as (

    select * from {{ ref('stg_ergast__races') }}

)

select
    laps.race_id,
    races.season,
    races.round,
    races.race_date,
    laps.driver_id,
    laps.lap,
    laps.position,
    laps.lap_time_ms
from laps
inner join races on laps.race_id = races.race_id

{% if is_incremental() %}
where laps.race_id not in (select race_id from {{ this }})
    or races.race_date >= (
        select min(race_date)
        from (
            select distinct race_date
            from {{ this }}
            order by race_date desc
            limit 2
        )
    )
{% endif %}
