{#- One row per driver per race with lap data and at least one green-flag lap. -#}
select
    race_id,
    driver_id,
    count(*)                    as green_laps,
    median(lap_time_ms)::number(12, 1) as median_green_lap_ms
from {{ ref('int_lap_times__green_flag') }}
where is_green_flag_lap
group by race_id, driver_id
