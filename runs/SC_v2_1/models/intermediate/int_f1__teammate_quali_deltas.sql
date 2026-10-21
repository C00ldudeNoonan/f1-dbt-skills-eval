-- One row per race, constructor and ordered teammate pair: how much faster (negative) or
-- slower (positive) `driver_id` was than `teammate_id` in qualifying, in the car they share.
-- To be fair when one driver is knocked out earlier, times are compared in the deepest session
-- BOTH drivers set a time in (Q3, else Q2, else Q1), never best-vs-best across sessions.
-- delta_pct = 100 * ln(driver_time / teammate_time): exactly antisymmetric between the two
-- orderings. Pairs further apart than max_abs_delta_pct are dropped as unrepresentative
-- (crash damage, traffic, red flags).
{% set max_abs_delta_pct = 5 %}

with entries as (

    select race_id, constructor_id, driver_id, q1_ms, q2_ms, q3_ms
    from {{ ref('fct_qualifying') }}

),

pairs as (

    select
        a.race_id,
        a.constructor_id,
        a.driver_id,
        b.driver_id as teammate_id,
        case
            when a.q3_ms is not null and b.q3_ms is not null then 'q3'
            when a.q2_ms is not null and b.q2_ms is not null then 'q2'
            when a.q1_ms is not null and b.q1_ms is not null then 'q1'
        end as compared_session,
        case
            when a.q3_ms is not null and b.q3_ms is not null then a.q3_ms
            when a.q2_ms is not null and b.q2_ms is not null then a.q2_ms
            when a.q1_ms is not null and b.q1_ms is not null then a.q1_ms
        end as driver_ms,
        case
            when a.q3_ms is not null and b.q3_ms is not null then b.q3_ms
            when a.q2_ms is not null and b.q2_ms is not null then b.q2_ms
            when a.q1_ms is not null and b.q1_ms is not null then b.q1_ms
        end as teammate_ms
    from entries as a
    inner join entries as b
        on a.race_id = b.race_id
        and a.constructor_id = b.constructor_id
        and a.driver_id <> b.driver_id

)

select
    pairs.race_id,
    races.season,
    pairs.constructor_id,
    pairs.driver_id,
    pairs.teammate_id,
    pairs.compared_session,
    (100 * ln(pairs.driver_ms::double / pairs.teammate_ms))::double as delta_pct
from pairs
inner join {{ ref('stg_f1__races') }} as races on races.race_id = pairs.race_id
where pairs.compared_session is not null
    and abs(100 * ln(pairs.driver_ms::double / pairs.teammate_ms)) <= {{ max_abs_delta_pct }}
