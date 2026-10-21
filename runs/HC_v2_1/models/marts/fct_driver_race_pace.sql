{#
    One row per driver per race that has lap data and at least one green-flag lap.
    The green-flag rules live in int_lap_green_flags.
#}
select
    race_id,
    driver_id,
    count(*) as green_laps,
    median(lap_time_ms) as median_green_lap_ms
from {{ ref('int_lap_green_flags') }}
where is_green_flag
group by race_id, driver_id
