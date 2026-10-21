{#
    One row per lap with lap data, flagged against the green-flag rules:
      - lap 1 is never green
      - a lap on which the driver made a pit stop is not green
      - the lap immediately after a pit stop is not green
      - a lap slower than slow_lap_multiplier x the race's fastest lap is not green
    Pit stop data starts in 2011, so has_pit_data is false for earlier races.
    Pit based exclusions cannot be applied there, which the flag makes visible.
#}
with laps as (

    select
        race_id,
        driver_id,
        lap_number,
        lap_ms

    from {{ ref('stg_f1__lap_times') }}
    where lap_ms is not null

),

race_fastest_lap as (

    select
        race_id,
        min(lap_ms) as race_fastest_lap_ms

    from laps
    group by race_id

),

pit_laps as (

    select distinct
        race_id,
        driver_id,
        lap_number

    from {{ ref('stg_f1__pit_stops') }}
    where lap_number is not null

),

races_with_pit_data as (

    select distinct race_id
    from {{ ref('stg_f1__pit_stops') }}

),

flagged as (

    select
        laps.race_id,
        laps.driver_id,
        laps.lap_number,
        laps.lap_ms,
        race_fastest_lap.race_fastest_lap_ms,
        pit_laps.lap_number is not null as is_pit_lap,
        previous_pit.lap_number is not null as is_post_pit_lap,
        laps.lap_ms > {{ var('slow_lap_multiplier') }} * race_fastest_lap.race_fastest_lap_ms as is_slow_lap,
        races_with_pit_data.race_id is not null as has_pit_data

    from laps
    inner join race_fastest_lap
        on laps.race_id = race_fastest_lap.race_id
    left join pit_laps
        on laps.race_id = pit_laps.race_id
        and laps.driver_id = pit_laps.driver_id
        and laps.lap_number = pit_laps.lap_number
    left join pit_laps as previous_pit
        on laps.race_id = previous_pit.race_id
        and laps.driver_id = previous_pit.driver_id
        and laps.lap_number - 1 = previous_pit.lap_number
    left join races_with_pit_data
        on laps.race_id = races_with_pit_data.race_id

)

select
    *,
    not (
        lap_number = 1
        or is_pit_lap
        or is_post_pit_lap
        or is_slow_lap
    ) as is_green_lap

from flagged
