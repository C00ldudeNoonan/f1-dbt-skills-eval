{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='race_id'
    )
}}

{#
    One row per driver per tyre stint, for races with pit stop data (2011 onwards).

    Stint boundaries come from the driver's pit stop laps. A stop on lap L ends the current
    stint at L, and the next stint starts at L + 1. The last stint ends on the driver's last
    recorded lap. A stop on the final lap leaves an empty trailing segment, which the inner
    join to laps drops.

    Incremental by race, with the same window as fct_lap_times. Each run replaces every stint of
    the races it touches, so corrected laps or new pit data change a race's stints in full.
#}
with races as (

    select
        race_id,
        season,
        round,
        race_date
    from {{ ref('stg_f1__races') }}
    where race_id in (select race_id from {{ ref('stg_f1__pit_stops') }})
    {{ recent_races_filter('race_date') }}

),

pit_laps as (

    select distinct
        pit_stops.race_id,
        pit_stops.driver_id,
        pit_stops.lap_number
    from {{ ref('stg_f1__pit_stops') }} as pit_stops
    inner join races
        on pit_stops.race_id = races.race_id

),

driver_last_lap as (

    select
        laps.race_id,
        laps.driver_id,
        max(laps.lap_number) as last_lap
    from {{ ref('stg_f1__lap_times') }} as laps
    inner join races
        on laps.race_id = races.race_id
    group by laps.race_id, laps.driver_id

),

segments as (

    select race_id, driver_id, lap_number as segment_end
    from pit_laps

    union all

    select race_id, driver_id, last_lap as segment_end
    from driver_last_lap

),

numbered as (

    select
        race_id,
        driver_id,
        segment_end,
        row_number() over (
            partition by race_id, driver_id
            order by segment_end
        ) as stint_number,
        coalesce(
            lag(segment_end) over (partition by race_id, driver_id order by segment_end),
            0
        ) + 1 as start_lap
    from segments

)

select
    numbered.race_id,
    races.season,
    races.round,
    races.race_date,
    numbered.driver_id,
    numbered.stint_number,
    numbered.start_lap,
    numbered.segment_end as end_lap,
    count(laps.lap_number) as stint_laps,
    avg(laps.lap_time_ms) as avg_lap_time_ms
from numbered
inner join races
    on numbered.race_id = races.race_id
inner join {{ ref('stg_f1__lap_times') }} as laps
    on numbered.race_id = laps.race_id
    and numbered.driver_id = laps.driver_id
    and laps.lap_number between numbered.start_lap and numbered.segment_end
group by
    numbered.race_id,
    races.season,
    races.round,
    races.race_date,
    numbered.driver_id,
    numbered.stint_number,
    numbered.start_lap,
    numbered.segment_end
