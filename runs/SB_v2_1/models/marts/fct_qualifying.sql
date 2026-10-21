-- Grain: one row per qualifying entry. Times are null when the driver set none.
with qualifying as (
    select
        qualify_id,
        race_id,
        driver_id,
        constructor_id,
        q1_ms,
        q2_ms,
        q3_ms,
        -- LEAST returns null if any argument is null, so mask nulls with a sentinel.
        nullif(least(coalesce(q1_ms, 2147483647), coalesce(q2_ms, 2147483647), coalesce(q3_ms, 2147483647)), 2147483647) as best_time_ms
    from {{ ref('stg_f1__qualifying') }}
),

with_pole as (
    select
        *,
        min(best_time_ms) over (partition by race_id) as pole_time_ms
    from qualifying
)

select
    qualify_id,
    race_id,
    driver_id,
    constructor_id,
    q1_ms,
    q2_ms,
    q3_ms,
    best_time_ms,
    best_time_ms - pole_time_ms as gap_to_pole_ms,
    ((best_time_ms - pole_time_ms) * 100.0 / pole_time_ms)::number(12, 6) as gap_to_pole_pct
from with_pole
