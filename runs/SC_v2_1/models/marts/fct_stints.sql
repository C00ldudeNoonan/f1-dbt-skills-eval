{{
    config(
        materialized='incremental',
        unique_key='race_id',
        incremental_strategy='delete+insert',
        on_schema_change='append_new_columns'
    )
}}

-- Stints are derived from fct_lap_times, so they must be rebuilt for exactly the
-- races whose laps may have changed: new races plus the two most recent in
-- fct_lap_times. Only races with pit stop data produce stints.
with pit_stop_races as (

    select distinct race_id from {{ ref('stg_f1__pit_stops') }}

),

laps as (

    select laps.*
    from {{ ref('fct_lap_times') }} as laps
    inner join pit_stop_races on pit_stop_races.race_id = laps.race_id
    {% if is_incremental() %}
    where laps.race_id in (
            select race_id
            from {{ ref('fct_lap_times') }}
            where season * 1000 + round >= (
                select min(race_order)
                from (
                    select distinct season * 1000 + round as race_order
                    from {{ ref('fct_lap_times') }}
                    order by race_order desc
                    limit 2
                )
            )
        )
        or laps.race_id not in (select race_id from {{ this }})
    {% endif %}

),

pit_laps as (

    select distinct race_id, driver_id, lap as pit_lap
    from {{ ref('stg_f1__pit_stops') }}

),

-- A stop on lap L ends the current stint on lap L, so a lap belongs to stint
-- 1 + (number of the driver's stops on earlier laps).
laps_with_stint as (

    select
        laps.race_id,
        laps.season,
        laps.round,
        laps.driver_id,
        laps.lap,
        laps.lap_time_ms,
        1 + count(pit_laps.pit_lap) as stint_number
    from laps
    left join pit_laps
        on pit_laps.race_id = laps.race_id
        and pit_laps.driver_id = laps.driver_id
        and pit_laps.pit_lap < laps.lap
    group by all

)

select
    race_id,
    season,
    round,
    driver_id,
    stint_number::integer as stint_number,
    min(lap)::integer as start_lap,
    max(lap)::integer as end_lap,
    count(*)::integer as stint_laps,
    avg(lap_time_ms)::double as avg_lap_time_ms
from laps_with_stint
group by all
