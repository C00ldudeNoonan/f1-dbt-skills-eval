with qualifying as (
    select * from {{ ref('stg_f1__qualifying') }}
),

races as (
    select * from {{ ref('int_f1__race_calendar') }}
),

best_times as (
    select
        *,
        -- Fastest of the sessions the driver actually set a time in.
        least(
            coalesce(q1_ms, q2_ms, q3_ms),
            coalesce(q2_ms, q1_ms, q3_ms),
            coalesce(q3_ms, q1_ms, q2_ms)
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
    with_pole.qualify_id,
    with_pole.race_id,
    races.season,
    races.round,
    with_pole.driver_id,
    with_pole.constructor_id,
    with_pole.qualifying_position,
    with_pole.q1_ms,
    with_pole.q2_ms,
    with_pole.q3_ms,
    with_pole.best_time_ms,
    with_pole.best_time_ms - with_pole.pole_time_ms as gap_to_pole_ms,
    ((with_pole.best_time_ms - with_pole.pole_time_ms) * 100
        / nullif(with_pole.pole_time_ms, 0))::float as gap_to_pole_pct
from with_pole
inner join races
    on with_pole.race_id = races.race_id
