{#- Green-flag filter: a lap is excluded if it is lap 1, a pit lap, the lap after a
    pit lap, or slower than this multiple of the race's fastest lap. -#}
{% set slow_lap_threshold = 1.3 %}

with laps as (

    select * from {{ ref('stg_f1__lap_times') }}

),

pit_laps as (

    select race_id, driver_id, lap as excluded_lap from {{ ref('stg_f1__pit_stops') }}
    union
    select race_id, driver_id, lap + 1 as excluded_lap from {{ ref('stg_f1__pit_stops') }}

),

race_fastest as (

    select race_id, min(lap_time_ms) as fastest_lap_ms
    from laps
    group by race_id

),

green_laps as (

    select laps.*
    from laps
    inner join race_fastest on race_fastest.race_id = laps.race_id
    left join pit_laps
        on pit_laps.race_id = laps.race_id
        and pit_laps.driver_id = laps.driver_id
        and pit_laps.excluded_lap = laps.lap
    where laps.lap > 1
        and pit_laps.excluded_lap is null
        and laps.lap_time_ms <= race_fastest.fastest_lap_ms * {{ slow_lap_threshold }}

)

select
    race_id,
    driver_id,
    count(*)::integer as green_laps,
    median(lap_time_ms)::double as median_green_lap_ms
from green_laps
group by race_id, driver_id
