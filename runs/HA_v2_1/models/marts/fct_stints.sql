{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='race_id'
    )
}}

{#
    Grain: one row per driver per stint (stint_id). Only races with pit stop data.

    Stint boundaries: stint 1 starts on lap 1. A pit stop on lap L ends the current stint
    at lap L, and the next stint starts at L+1. The final stint ends on the driver's last
    recorded lap. A stint with no recorded laps is dropped (for example, a stop on the
    last lap leaves an empty final stint). Lap numbers are contiguous from 1 in the
    source, so stint_laps is the same as end_lap - start_lap + 1.

    Incremental by race, with the same rule as fct_lap_times: the two most recent races
    are rebuilt whole (delete+insert on race_id), so late lap corrections and new races
    flow through without a full refresh.
#}
with races as (

    -- Only races that have pit stop data.
    select races.race_id, races.race_date
    from {{ ref('stg_f1__races') }} as races
    where races.race_id in (select race_id from {{ ref('stg_f1__pit_stops') }})

{% if is_incremental() %}
        and races.race_date >= (
            select min(race_date)
            from (
                select distinct race_date
                from {{ this }}
                order by race_date desc
                limit 2
            )
        )
{% endif %}

),

pit_stops as (

    select distinct
        pit_stops.race_id,
        pit_stops.driver_id,
        pit_stops.lap
    from {{ ref('stg_f1__pit_stops') }} as pit_stops
    inner join races
        on pit_stops.race_id = races.race_id

),

driver_races as (

    select
        lap_times.race_id,
        lap_times.driver_id,
        max(lap_times.lap) as last_lap
    from {{ ref('stg_f1__lap_times') }} as lap_times
    inner join races
        on lap_times.race_id = races.race_id
    group by lap_times.race_id, lap_times.driver_id

),

pit_numbered as (

    select
        race_id,
        driver_id,
        lap as pit_lap,
        row_number() over (partition by race_id, driver_id order by lap) as pit_number
    from pit_stops

),

pit_counts as (

    select race_id, driver_id, count(*) as pit_count
    from pit_numbered
    group by race_id, driver_id

),

-- Stint k ends at pit k. The last stint (pit_count + 1) ends at the last recorded lap.
stint_ends as (

    select
        race_id,
        driver_id,
        pit_number as stint_number,
        pit_lap as end_lap
    from pit_numbered

    union all

    select
        driver_races.race_id,
        driver_races.driver_id,
        coalesce(pit_counts.pit_count, 0) + 1 as stint_number,
        driver_races.last_lap as end_lap
    from driver_races
    left join pit_counts
        on driver_races.race_id = pit_counts.race_id
        and driver_races.driver_id = pit_counts.driver_id

),

stints as (

    select
        race_id,
        driver_id,
        stint_number,
        coalesce(
            lag(end_lap) over (partition by race_id, driver_id order by stint_number) + 1,
            1
        ) as start_lap,
        end_lap
    from stint_ends

),

stint_laps as (

    select
        stints.race_id,
        stints.driver_id,
        stints.stint_number,
        stints.start_lap,
        stints.end_lap,
        count(lap_times.lap) as stint_laps,
        avg(lap_times.lap_time_ms) as avg_lap_time_ms
    from stints
    inner join {{ ref('stg_f1__lap_times') }} as lap_times
        on stints.race_id = lap_times.race_id
        and stints.driver_id = lap_times.driver_id
        and lap_times.lap between stints.start_lap and stints.end_lap
    group by
        stints.race_id,
        stints.driver_id,
        stints.stint_number,
        stints.start_lap,
        stints.end_lap

)

select
    stint_laps.race_id::varchar || '-' || stint_laps.driver_id::varchar || '-' || stint_laps.stint_number::varchar as stint_id,
    races.race_id,
    races.race_date,
    stint_laps.driver_id,
    stint_laps.stint_number,
    stint_laps.start_lap,
    stint_laps.end_lap,
    stint_laps.stint_laps,
    stint_laps.avg_lap_time_ms
from stint_laps
inner join races
    on stint_laps.race_id = races.race_id
