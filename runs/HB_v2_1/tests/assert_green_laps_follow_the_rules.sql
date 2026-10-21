{#
    No green-flag lap may be lap 1, a pit lap, the lap after a pit stop, or a lap
    slower than the race's slow lap threshold. Every counted lap must be green.
#}
select *
from {{ ref('int_lap_flags') }}
where is_green_lap
    and (
        lap_number = 1
        or is_pit_lap
        or is_post_pit_lap
        or lap_ms > {{ var('slow_lap_multiplier') }} * race_fastest_lap_ms
    )
