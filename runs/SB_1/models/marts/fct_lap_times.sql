{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['race_id', 'driver_id', 'lap'],
        on_schema_change='append_new_columns'
    )
}}

-- Incremental on race chronology (season, round). Each run reprocesses every race at or after
-- the second-most-recent race already loaded in this table: that picks up brand-new races and
-- also the timing provider's corrections to the two latest loaded races. The merge on
-- (race_id, driver_id, lap) overwrites corrected laps in place. Older history is left alone;
-- use `--full-refresh` if a correction ever lands further back.
with races as (

    select race_id, season, round, race_date from {{ ref('stg_f1__races') }}

),

laps as (

    select * from {{ ref('stg_f1__lap_times') }}

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
where races.season * 1000 + races.round >= (
    select min(race_order)
    from (
        select distinct season * 1000 + round as race_order
        from {{ this }}
        order by race_order desc
        limit 2
    )
)
{% endif %}
