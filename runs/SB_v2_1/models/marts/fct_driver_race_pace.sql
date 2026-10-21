-- Grain: one row per driver per race that has lap data and at least one green-flag lap.
-- Green lap = not lap 1, not a pit-stop lap, not the lap after a pit stop, and not slower than
-- 130% of the fastest lap anyone set in that race.
with laps as (
    select * from {{ ref('stg_f1__lap_times') }}
),

pit_laps as (
    select distinct race_id, driver_id, lap as excluded_lap from {{ ref('stg_f1__pit_stops') }}
    union
    select distinct race_id, driver_id, lap + 1 from {{ ref('stg_f1__pit_stops') }}
),

race_fastest as (
    select race_id, min(lap_time_ms) as fastest_lap_ms
    from laps
    group by 1
),

green as (
    select laps.race_id, laps.driver_id, laps.lap, laps.lap_time_ms
    from laps
    inner join race_fastest on race_fastest.race_id = laps.race_id
    left join pit_laps
        on pit_laps.race_id = laps.race_id
        and pit_laps.driver_id = laps.driver_id
        and pit_laps.excluded_lap = laps.lap
    where laps.lap > 1
      and pit_laps.excluded_lap is null
      and laps.lap_time_ms <= race_fastest.fastest_lap_ms * 1.3
)

select
    race_id,
    driver_id,
    count(*)::integer as green_laps,
    median(lap_time_ms)::number(12, 1) as median_green_lap_ms
from green
group by 1, 2
