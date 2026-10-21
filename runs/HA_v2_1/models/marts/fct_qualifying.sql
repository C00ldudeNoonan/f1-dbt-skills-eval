{#
    Grain: one row per qualifying entry (qualify_id).
    best_time_ms is the fastest of Q1, Q2 and Q3 (null if none set). LEAST() returns
    null when any argument is null, so nulls are replaced by a sentinel first.
    gap_to_pole_pct is the gap as a percentage of the pole time (0.512 means 0.512%).
#}
with qualifying as (

    select
        qualifying.*,
        races.season
    from {{ ref('stg_f1__qualifying') }} as qualifying
    inner join {{ ref('stg_f1__races') }} as races
        on qualifying.race_id = races.race_id

),

best_times as (

    select
        *,
        nullif(
            least(
                coalesce(q1_ms, 2147483647),
                coalesce(q2_ms, 2147483647),
                coalesce(q3_ms, 2147483647)
            ),
            2147483647
        ) as best_time_ms
    from qualifying

),

with_pole as (

    select
        *,
        min(best_time_ms) over (partition by race_id) as pole_time_ms
    from best_times

)

select
    qualify_id,
    race_id,
    season,
    driver_id,
    constructor_id,
    position_number as qualifying_position,
    q1_ms,
    q2_ms,
    q3_ms,
    best_time_ms,
    pole_time_ms,
    best_time_ms - pole_time_ms as gap_to_pole_ms,
    (best_time_ms - pole_time_ms) / pole_time_ms * 100 as gap_to_pole_pct
from with_pole
