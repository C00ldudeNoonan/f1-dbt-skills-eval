{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='race_id',
        on_schema_change='fail'
    )
}}

-- One row per driver per lap per race.
-- Incremental on race: each run replaces every race dated within the two most recent races already loaded
-- (so reissued timing corrections flow through) and inserts races newer than those.
-- delete+insert on race_id replaces a race's full set of laps, so removed laps are also dropped.
with lap_times as (

    select * from {{ ref('stg_f1__lap_times') }}

),

races as (

    select * from {{ ref('stg_f1__races') }}

),

final as (

    select
        lap_times.race_id,
        races.season,
        races.round,
        races.race_date,
        lap_times.driver_id,
        lap_times.lap,
        lap_times.position,
        lap_times.lap_time_ms,
        lap_times.lap_time_text
    from lap_times
    inner join races
        on races.race_id = lap_times.race_id

)

select *
from final
{% if is_incremental() %}
where race_date >= (
    select min(race_date)
    from (
        select distinct race_date
        from {{ this }}
        order by race_date desc
        limit 2
    )
)
{% endif %}
