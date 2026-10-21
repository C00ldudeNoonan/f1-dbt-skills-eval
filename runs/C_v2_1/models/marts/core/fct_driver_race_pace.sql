-- Green-flag race pace. A lap is green unless it is lap 1, a lap on which the
-- driver pitted, the lap after a pit stop, or slower than 130% of the fastest
-- lap anyone set in the race. Pit stop data only exists from 2011, so before
-- then only the lap-1 and 130% rules can apply.

with lap_times as (
    select * from {{ ref('stg_f1__lap_times') }}
),

pit_stops as (
    select * from {{ ref('stg_f1__pit_stops') }}
),

race_fastest_lap as (
    select
        race_id,
        min(lap_time_ms) as fastest_lap_ms
    from lap_times
    group by race_id
),

pit_affected_laps as (
    select race_id, driver_id, lap from pit_stops
    union
    select race_id, driver_id, lap + 1 from pit_stops
),

green_laps as (
    select
        lap_times.race_id,
        lap_times.driver_id,
        lap_times.lap_time_ms
    from lap_times
    inner join race_fastest_lap
        on lap_times.race_id = race_fastest_lap.race_id
    left join pit_affected_laps
        on lap_times.race_id = pit_affected_laps.race_id
        and lap_times.driver_id = pit_affected_laps.driver_id
        and lap_times.lap = pit_affected_laps.lap
    where lap_times.lap <> 1
        and pit_affected_laps.lap is null
        and lap_times.lap_time_ms <= race_fastest_lap.fastest_lap_ms * 1.3
)

select
    race_id,
    driver_id,
    count(*) as green_laps,
    median(lap_time_ms)::number(12, 1) as median_green_lap_ms
from green_laps
group by race_id, driver_id
