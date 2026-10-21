{#-
  Every lap with flags explaining whether it counts as a green-flag lap.
  A green-flag lap is any lap except:
    - lap 1
    - a lap on which the driver made a pit stop (in-lap)
    - the lap immediately after a pit stop (out-lap)
    - a lap slower than green_lap_max_ratio (130%) of the fastest lap anyone set in the race
-#}
with laps as (
    select * from {{ ref('stg_ergast__lap_times') }}
),

pit_laps as (
    select distinct race_id, driver_id, lap
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
        race_fastest.race_fastest_lap_ms,
        laps.lap = 1                                    as is_first_lap,
        pit_in.lap is not null                          as is_pit_lap,
        pit_out.lap is not null                         as is_lap_after_pit,
        laps.lap_time_ms > race_fastest.race_fastest_lap_ms * {{ var('green_lap_max_ratio') }}
                                                        as is_slow_lap
    from laps
    inner join race_fastest
        on laps.race_id = race_fastest.race_id
    left join pit_laps as pit_in
        on laps.race_id = pit_in.race_id
        and laps.driver_id = pit_in.driver_id
        and laps.lap = pit_in.lap
    left join pit_laps as pit_out
        on laps.race_id = pit_out.race_id
        and laps.driver_id = pit_out.driver_id
        and laps.lap = pit_out.lap + 1
)

select
    *,
    not (is_first_lap or is_pit_lap or is_lap_after_pit or is_slow_lap) as is_green_flag_lap
from flagged
