{{
    config(
        materialized='incremental',
        unique_key='race_id',
        incremental_strategy='delete+insert',
        on_schema_change='append_new_columns'
    )
}}

with laps as (

    select * from {{ ref('stg_f1__lap_times') }}

),

races as (

    select * from {{ ref('stg_f1__races') }}

),

joined as (

    select
        laps.race_id,
        races.season,
        races.round,
        laps.driver_id,
        laps.lap,
        laps.position,
        laps.lap_time_ms
    from laps
    inner join races on races.race_id = laps.race_id

)

select * from joined
{% if is_incremental() %}
where {{ recent_races_filter('season * 1000 + round', 'season * 1000 + round') }}
{% endif %}
