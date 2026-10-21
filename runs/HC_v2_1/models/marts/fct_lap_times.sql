{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='race_id'
    )
}}

{#
    One row per driver per lap per race. Incremental by race: each run replaces every lap of
    the races it touches, so a corrected lap time, or a lap that disappears in a correction,
    flows through without a full refresh. Those races are the new races plus the two most recent
    races already loaded. Older races are never touched.
#}
with races as (

    select
        race_id,
        season,
        round,
        race_date
    from {{ ref('stg_f1__races') }}
    where true
    {{ recent_races_filter('race_date') }}

)

select
    races.race_id,
    races.season,
    races.round,
    races.race_date,
    laps.driver_id,
    laps.lap_number as lap,
    laps.lap_position as position,
    laps.lap_time_ms
from {{ ref('stg_f1__lap_times') }} as laps
inner join races
    on laps.race_id = races.race_id
