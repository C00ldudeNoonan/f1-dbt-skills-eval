-- One row per driver per race per teammate (both orderings): the driver's
-- qualifying gap to a teammate in the same car, measured in the last
-- session both set a time in (Q3, else Q2, else Q1; the single session before
-- 2006), so both drivers ran on the same track at the same time.
-- gap_pct = 100 * ln(driver / teammate): negative means faster; symmetric, so
-- the two orderings of a pair are exact negatives.
with qualifying as (

    select * from {{ ref('fct_qualifying') }}

),

pairs as (

    select
        driver.season,
        driver.race_id,
        driver.constructor_id,
        driver.driver_id,
        teammate.driver_id as teammate_id,
        case
            when driver.q3_ms is not null and teammate.q3_ms is not null then 'q3'
            when driver.q2_ms is not null and teammate.q2_ms is not null then 'q2'
            when driver.q1_ms is not null and teammate.q1_ms is not null then 'q1'
        end as session_compared,
        case
            when driver.q3_ms is not null and teammate.q3_ms is not null then 100 * ln(driver.q3_ms::float / teammate.q3_ms::float)
            when driver.q2_ms is not null and teammate.q2_ms is not null then 100 * ln(driver.q2_ms::float / teammate.q2_ms::float)
            when driver.q1_ms is not null and teammate.q1_ms is not null then 100 * ln(driver.q1_ms::float / teammate.q1_ms::float)
        end as gap_pct
    from qualifying as driver
    inner join qualifying as teammate
        on driver.race_id = teammate.race_id
        and driver.constructor_id = teammate.constructor_id
        and driver.driver_id != teammate.driver_id

)

select
    *,
    abs(gap_pct) <= {{ var('teammate_gap_max_pct') }} as is_representative
from pairs
where gap_pct is not null
