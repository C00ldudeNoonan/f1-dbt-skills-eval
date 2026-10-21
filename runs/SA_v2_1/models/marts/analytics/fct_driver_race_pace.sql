-- Green-flag laps: every lap except lap 1, a driver's pit-stop lap, the lap right
-- after a pit stop, and laps slower than 130% of the race's fastest lap (any driver,
-- any lap). The fastest lap is taken over all recorded laps, before any exclusion.
with laps as (

    select
        race_id,
        driver_id,
        lap,
        lap_time_ms,
        min(lap_time_ms) over (partition by race_id) as race_fastest_lap_ms
    from {{ ref('stg_ergast__lap_times') }}

),

pit_affected_laps as (

    select distinct race_id, driver_id, lap as affected_lap
    from {{ ref('stg_ergast__pit_stops') }}

    union

    select distinct race_id, driver_id, lap + 1 as affected_lap
    from {{ ref('stg_ergast__pit_stops') }}

),

green_laps as (

    select laps.*
    from laps
    left join pit_affected_laps
        on laps.race_id = pit_affected_laps.race_id
        and laps.driver_id = pit_affected_laps.driver_id
        and laps.lap = pit_affected_laps.affected_lap
    where laps.lap > 1
        and pit_affected_laps.affected_lap is null
        and laps.lap_time_ms <= 1.3 * laps.race_fastest_lap_ms

)

select
    race_id,
    driver_id,
    count(*) as green_laps,
    median(lap_time_ms) as median_green_lap_ms
from green_laps
group by race_id, driver_id
