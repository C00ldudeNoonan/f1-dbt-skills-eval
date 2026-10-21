{#
    No lap flagged as green may also be lap 1, a pit lap, the lap after a pit stop,
    or a lap over 130% of the race's fastest lap.
#}
select
    race_id,
    driver_id,
    lap_number
from {{ ref('int_lap_green_flags') }}
where is_green_flag
    and (
        is_first_lap
        or is_pit_lap
        or is_lap_after_pit
        or is_over_130_pct_of_fastest
    )
