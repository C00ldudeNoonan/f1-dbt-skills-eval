{#
    One row per driver per lap, with the green-flag rules applied. A lap is green unless:
      - it is lap 1 (standing start),
      - the driver pitted on that lap,
      - the driver pitted on the lap before (the out-lap after a stop),
      - it is slower than 130% of the fastest lap set by any driver in that race.

    Pit stop data starts in 2011. For earlier races no lap can be excluded for a stop,
    so only the lap 1 and 130% rules apply there.
#}
with laps as (

    select * from {{ ref('stg_f1__lap_times') }}

),

pit_stop_laps as (

    select distinct race_id, driver_id, lap_number
    from {{ ref('stg_f1__pit_stops') }}

),

race_fastest_lap as (

    select
        race_id,
        min(lap_time_ms) as fastest_lap_ms
    from laps
    group by race_id

),

flagged as (

    select
        laps.race_id,
        laps.driver_id,
        laps.lap_number,
        laps.lap_time_ms,
        race_fastest_lap.fastest_lap_ms,
        laps.lap_number = 1 as is_first_lap,
        pit_stop_laps.lap_number is not null as is_pit_lap,
        lap_before_pit.lap_number is not null as is_lap_after_pit,
        laps.lap_time_ms > 1.3 * race_fastest_lap.fastest_lap_ms as is_over_130_pct_of_fastest
    from laps
    inner join race_fastest_lap
        on laps.race_id = race_fastest_lap.race_id
    left join pit_stop_laps
        on laps.race_id = pit_stop_laps.race_id
        and laps.driver_id = pit_stop_laps.driver_id
        and laps.lap_number = pit_stop_laps.lap_number
    left join pit_stop_laps as lap_before_pit
        on laps.race_id = lap_before_pit.race_id
        and laps.driver_id = lap_before_pit.driver_id
        and laps.lap_number = lap_before_pit.lap_number + 1

)

select
    *,
    not (
        is_first_lap
        or is_pit_lap
        or is_lap_after_pit
        or is_over_130_pct_of_fastest
    ) as is_green_flag
from flagged
