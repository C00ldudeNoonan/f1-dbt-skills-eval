{#
    One row per lap. Flags say why a lap is excluded from "green flag" pace:
      - is_first_lap: lap 1 (standing start, traffic and fuel effects).
      - is_pit_lap: the driver made a pit stop on this lap.
      - is_post_pit_lap: the lap immediately after a pit stop (out-lap cost).
      - is_slower_than_threshold: slower than slow_lap_threshold_pct of the fastest
        lap set by anyone in the race.
    Pit data starts in 2011, so pit flags are always false before then (see
    fct_driver_race_pace.pit_stop_data_available).
#}
with lap_times as (

    select race_id, driver_id, lap, lap_time_ms
    from {{ ref('stg_f1__lap_times') }}

),

race_fastest_lap as (

    select race_id, min(lap_time_ms) as fastest_lap_ms
    from lap_times
    group by race_id

),

pit_stops as (

    select race_id, driver_id, lap
    from {{ ref('stg_f1__pit_stops') }}

)

select
    lap_times.race_id,
    lap_times.driver_id,
    lap_times.lap,
    lap_times.lap_time_ms,
    race_fastest_lap.fastest_lap_ms,
    lap_times.lap = 1 as is_first_lap,
    exists (
        select 1
        from pit_stops
        where pit_stops.race_id = lap_times.race_id
            and pit_stops.driver_id = lap_times.driver_id
            and pit_stops.lap = lap_times.lap
    ) as is_pit_lap,
    exists (
        select 1
        from pit_stops
        where pit_stops.race_id = lap_times.race_id
            and pit_stops.driver_id = lap_times.driver_id
            and pit_stops.lap = lap_times.lap - 1
    ) as is_post_pit_lap,
    lap_times.lap_time_ms
        > {{ var('slow_lap_threshold_pct') }} / 100.0 * race_fastest_lap.fastest_lap_ms
        as is_slower_than_threshold
from lap_times
inner join race_fastest_lap
    on lap_times.race_id = race_fastest_lap.race_id
