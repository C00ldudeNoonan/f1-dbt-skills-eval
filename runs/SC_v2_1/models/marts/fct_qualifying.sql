with qualifying as (

    select * from {{ ref('stg_f1__qualifying') }}

),

best as (

    select
        *,
        least_ignore_nulls(q1_ms, q2_ms, q3_ms) as best_time_ms
    from qualifying

),

with_pole as (

    select
        *,
        min(best_time_ms) over (partition by race_id) as pole_time_ms
    from best

)

select
    qualify_id,
    race_id,
    driver_id,
    constructor_id,
    qualifying_position,
    q1_ms,
    q2_ms,
    q3_ms,
    best_time_ms,
    best_time_ms - pole_time_ms as gap_to_pole_ms,
    (best_time_ms - pole_time_ms)::double * 100 / pole_time_ms as gap_to_pole_pct
from with_pole
