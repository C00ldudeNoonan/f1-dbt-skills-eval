-- Race pace on green-flag laps. A green-flag lap is any lap except:
--   * lap 1
--   * a lap on which the driver pitted, and the lap immediately after
--   * a lap slower than green_lap_max_ratio (130%) of the race's fastest lap
with laps as (

    select * from {{ ref('stg_ergast__lap_times') }}

),

-- Laps excluded because of a pit stop: the in-lap and the lap after it.
pit_affected_laps as (

    select race_id, driver_id, lap
    from {{ ref('stg_ergast__pit_stops') }}

    union

    select race_id, driver_id, lap + 1
    from {{ ref('stg_ergast__pit_stops') }}

),

race_fastest as (

    select race_id, min(lap_time_ms) as race_fastest_lap_ms
    from laps
    group by race_id

),

flagged as (

    select
        laps.race_id,
        laps.driver_id,
        laps.lap,
        laps.lap_time_ms,
        laps.lap > 1
            and pit_affected_laps.lap is null
            and laps.lap_time_ms <= race_fastest.race_fastest_lap_ms * {{ var('green_lap_max_ratio') }}
            as is_green_lap
    from laps
    inner join race_fastest
        on laps.race_id = race_fastest.race_id
    left join pit_affected_laps
        on laps.race_id = pit_affected_laps.race_id
        and laps.driver_id = pit_affected_laps.driver_id
        and laps.lap = pit_affected_laps.lap

)

select
    race_id,
    driver_id,
    count(*) as green_laps,
    median(lap_time_ms) as median_green_lap_ms
from flagged
where is_green_lap
group by race_id, driver_id
