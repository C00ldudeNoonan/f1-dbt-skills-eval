{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='race_id',
        on_schema_change='append_new_columns'
    )
}}

-- One row per driver per lap per race. Raw has no load timestamp, so incremental runs
-- re-load, whole races at a time (delete+insert on race_id, so laps removed by a
-- reissue disappear too):
--   * every race newer than the latest race already in this table (new Grands Prix), and
--   * the two most recent races already loaded (the provider reissues corrected times for these).
-- Older history is left untouched. Use --full-refresh to rebuild everything.
with laps as (
    select
        laps.race_id,
        races.season,
        races.round,
        races.race_date,
        laps.driver_id,
        laps.lap,
        laps.position,
        laps.lap_time_ms
    from {{ ref('stg_lap_times') }} as laps
    inner join {{ ref('stg_races') }} as races using (race_id)
)

select * from laps
{% if is_incremental() %}
where race_date >= (
    -- date of the 2nd most recent loaded race (or the only one, if just one is loaded)
    select coalesce(min(race_date), '1900-01-01'::date)
    from (
        select distinct race_date
        from {{ this }}
        order by race_date desc
        limit 2
    )
)
{% endif %}
