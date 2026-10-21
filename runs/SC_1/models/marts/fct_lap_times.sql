{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='race_id',
        on_schema_change='fail'
    )
}}

-- Incremental by race. The raw table has no load timestamp, so recency is judged by race date:
-- each run reprocesses races newer than what is loaded plus the two most recent races already
-- loaded, because the timing provider can reissue corrected laps for those. delete+insert on
-- race_id replaces a race wholesale, so corrections (and dropped laps) flow through, and
-- older history is never touched. Use --full-refresh to rebuild everything.
with races as (

    select race_id, season, round, race_date
    from {{ ref('stg_f1__races') }}

),

lap_times as (

    select * from {{ ref('stg_f1__lap_times') }}

)

select
    lap_times.race_id,
    races.season,
    races.round,
    races.race_date,
    lap_times.driver_id,
    lap_times.lap,
    lap_times.position,
    lap_times.lap_time_ms
from lap_times
inner join races on lap_times.race_id = races.race_id
{% if is_incremental() %}
where races.race_date >= (
    -- start date of the 2nd most recent race in this table (or the only one, if just one)
    select coalesce(min(race_date), '1900-01-01'::date)
    from (
        select distinct race_date
        from {{ this }}
        qualify dense_rank() over (order by race_date desc) <= 2
    )
)
{% endif %}
