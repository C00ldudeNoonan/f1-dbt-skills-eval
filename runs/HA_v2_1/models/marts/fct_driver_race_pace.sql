{#
    Grain: one row per driver per race that has lap data and at least one green-flag lap.
    A green-flag lap is any lap except: lap 1, a pit lap, the lap after a pit stop, or a lap
    slower than slow_lap_threshold_pct of the race's fastest lap (see int_lap_flags).
    pit_stop_data_available is false for races before 2011 (no pit data), so pit-related
    exclusions were not applied there.
#}
with green_laps as (

    select
        race_id,
        driver_id,
        lap_time_ms
    from {{ ref('int_lap_flags') }}
    where not is_first_lap
        and not is_pit_lap
        and not is_post_pit_lap
        and not is_slower_than_threshold

),

race_pace as (

    select
        race_id,
        driver_id,
        count(*) as green_laps,
        median(lap_time_ms) as median_green_lap_ms
    from green_laps
    group by race_id, driver_id

),

races_with_pit_data as (

    select distinct race_id
    from {{ ref('stg_f1__pit_stops') }}

)

select
    races.season,
    race_pace.race_id,
    race_pace.driver_id,
    race_pace.green_laps,
    race_pace.median_green_lap_ms,
    races_with_pit_data.race_id is not null as pit_stop_data_available
from race_pace
inner join {{ ref('stg_f1__races') }} as races
    on race_pace.race_id = races.race_id
left join races_with_pit_data
    on race_pace.race_id = races_with_pit_data.race_id
