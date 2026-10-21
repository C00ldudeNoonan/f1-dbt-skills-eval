{#
    One row per qualifying entry. A driver's best time is the fastest of Q1, Q2 and Q3.
    The pole time is the fastest best time in the same race. Gaps are null when the driver
    did not set a time.
#}
with qualifying as (

    select * from {{ ref('stg_f1__qualifying') }}

),

races as (

    select race_id, season from {{ ref('stg_f1__races') }}

),

best_times as (

    select
        qualifying.*,
        -- LEAST returns NULL if any argument is NULL, so each argument falls back to the
        -- next available session. Together they give the minimum of the non-null times.
        least(
            coalesce(q1_ms, q2_ms, q3_ms),
            coalesce(q2_ms, q1_ms, q3_ms),
            coalesce(q3_ms, q2_ms, q1_ms)
        ) as best_time_ms
    from qualifying

),

with_pole as (

    select
        best_times.*,
        min(best_time_ms) over (partition by race_id) as pole_time_ms
    from best_times

)

select
    with_pole.qualify_id,
    with_pole.race_id,
    races.season,
    with_pole.driver_id,
    with_pole.constructor_id,
    with_pole.position as qualifying_position,
    with_pole.q1_ms,
    with_pole.q2_ms,
    with_pole.q3_ms,
    with_pole.best_time_ms,
    with_pole.pole_time_ms,
    with_pole.best_time_ms - with_pole.pole_time_ms as gap_to_pole_ms,
    (with_pole.best_time_ms - with_pole.pole_time_ms) / with_pole.pole_time_ms * 100 as gap_to_pole_pct
from with_pole
left join races
    on with_pole.race_id = races.race_id
