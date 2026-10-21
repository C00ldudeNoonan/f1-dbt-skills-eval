{#
    One row per driver per lap per race (race_id, driver_id, lap).

    Incremental, with a delete+insert keyed on race_id. Each run reprocesses every
    race dated on or after the second most recent race already loaded. That covers
    new races and the timing provider's corrected laps for the last two races. A
    delete+insert on race_id also removes laps the correction dropped, as long as the
    corrected race still has at least one lap. Races older than that window are not
    reprocessed. Use --full-refresh to rebuild everything.
#}
{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='race_id',
    on_schema_change='fail'
) }}

with laps as (

    select
        lap_times.race_id,
        lap_times.driver_id,
        lap_times.lap_number,
        lap_times.position,
        lap_times.lap_ms,
        races.season,
        races.round,
        races.race_date

    from {{ ref('stg_f1__lap_times') }} as lap_times
    inner join {{ ref('stg_f1__races') }} as races
        on lap_times.race_id = races.race_id

    {% if is_incremental() %}
    where races.race_date >= coalesce(
        (
            select min(recent.race_date)
            from (
                select race_date
                from {{ this }}
                group by race_date
                order by race_date desc
                limit 2
            ) as recent
        ),
        '1900-01-01'::date
    )
    {% endif %}

)

select
    race_id,
    season,
    round,
    race_date,
    driver_id,
    lap_number as lap,
    position,
    lap_ms as lap_time_ms

from laps
