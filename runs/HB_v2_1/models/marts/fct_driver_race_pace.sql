{#
    One row per driver per race that has lap data and at least one green-flag lap.
    Green-flag rules live in int_lap_flags.
#}
with lap_flags as (

    select * from {{ ref('int_lap_flags') }}

)

select
    race_id,
    driver_id,
    count(*) as total_laps,
    count_if(is_green_lap) as green_laps,
    median(iff(is_green_lap, lap_ms, null)) as median_green_lap_ms,
    boolor_agg(has_pit_data) as has_pit_data

from lap_flags
group by race_id, driver_id
having count_if(is_green_lap) > 0
