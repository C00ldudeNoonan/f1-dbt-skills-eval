-- One row per qualifying entry, with each driver's best session time and the
-- gap to the fastest best time in the same race.
with qualifying as (

    select * from {{ ref('stg_ergast__qualifying') }}

),

best_times as (

    select
        *,
        -- least() returns null if any argument is null, so fold the nulls away.
        nullif(least(
            coalesce(q1_ms, 2147483647),
            coalesce(q2_ms, 2147483647),
            coalesce(q3_ms, 2147483647)
        ), 2147483647) as best_time_ms
    from qualifying

),

with_pole as (

    select
        *,
        min(best_time_ms) over (partition by race_id) as pole_time_ms
    from best_times

)

select
    with_pole.qualify_id,
    with_pole.race_id,
    races.season,
    races.round,
    with_pole.driver_id,
    with_pole.constructor_id,
    with_pole.car_number,
    with_pole.qualifying_position,
    with_pole.q1_ms,
    with_pole.q2_ms,
    with_pole.q3_ms,
    with_pole.best_time_ms,
    with_pole.pole_time_ms,
    with_pole.best_time_ms - with_pole.pole_time_ms as gap_to_pole_ms,
    round((with_pole.best_time_ms - with_pole.pole_time_ms) * 100.0 / with_pole.pole_time_ms, 6)
        as gap_to_pole_pct
from with_pole
inner join {{ ref('stg_ergast__races') }} as races
    on with_pole.race_id = races.race_id
