{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='race_id'
    )
}}

{#
    Grain: one row per driver per lap per race (lap_id).

    Incremental by race. Each run reprocesses the two most recent races already in
    this table, plus any newer races, and replaces each race's rows as a whole
    (delete+insert on race_id). That is how the timing provider's corrected lap times
    for the last two races flow through without a full refresh. Older races are not
    touched.
#}
with laps as (

    select
        lap_times.race_id,
        lap_times.driver_id,
        lap_times.lap,
        lap_times.position_number as position,
        lap_times.lap_time_ms,
        races.season,
        races.round,
        races.race_date
    from {{ ref('stg_f1__lap_times') }} as lap_times
    inner join {{ ref('stg_f1__races') }} as races
        on lap_times.race_id = races.race_id

    {% if is_incremental() %}
    -- Reprocess from the second most recent race already loaded, so the last two races
    -- are rebuilt. Races landing after that are picked up too.
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

)

select
    laps.race_id::varchar || '-' || laps.driver_id::varchar || '-' || laps.lap::varchar as lap_id,
    laps.race_id,
    laps.season,
    laps.round,
    laps.race_date,
    laps.driver_id,
    laps.lap,
    laps.position,
    laps.lap_time_ms
from laps
