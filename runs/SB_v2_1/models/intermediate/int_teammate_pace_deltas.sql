-- Grain: one row per race, constructor, driver and teammate (both orderings) with how much faster or slower
-- the driver was than the teammate IN THE SAME CAR on the same weekend. Percent of lap time, so tracks and
-- eras are comparable; NEGATIVE = the driver was FASTER than the teammate.
--
-- qual_delta_pct:      compares the latest qualifying session BOTH drivers set a time in (Q3, else Q2, else Q1), so
--                      a driver knocked out in Q1 is not compared with a teammate's Q3 lap on a faster, rubberier
--                      track. Pairs further apart than 10% are dropped (crashes, red flags, mechanical trouble,
--                      the Q1 typo in the raw data), they say nothing about driver skill.
-- race_pace_delta_pct: compares median green-flag lap times (fct_driver_race_pace, 10+ green laps each), which
--                      strips pit stops, lap one and slow laps. Same 10% guard. Available from 1996.
{% set max_abs_delta = var('teammate_max_abs_delta_pct', 10) %}

with qualifying_pairs as (
    select
        a.race_id,
        a.constructor_id,
        a.driver_id,
        b.driver_id as teammate_id,
        case
            when a.q3_ms is not null and b.q3_ms is not null then 3
            when a.q2_ms is not null and b.q2_ms is not null then 2
            when a.q1_ms is not null and b.q1_ms is not null then 1
        end as qual_session,
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
    from {{ ref('fct_qualifying') }} as a
    inner join {{ ref('fct_qualifying') }} as b
        on a.race_id = b.race_id
        and a.constructor_id = b.constructor_id
        and a.driver_id <> b.driver_id
),

qualifying as (
    select
        race_id, constructor_id, driver_id, teammate_id, qual_session,
        100.0 * (driver_ms - teammate_ms) / ((driver_ms + teammate_ms) / 2) as qual_delta_pct
    from qualifying_pairs
    where qual_session is not null
),

race_entries as (
    select distinct race_id, constructor_id, driver_id from {{ ref('fct_results') }}
),

pace as (
    select entries.race_id, entries.constructor_id, entries.driver_id, pace.median_green_lap_ms
    from {{ ref('fct_driver_race_pace') }} as pace
    inner join race_entries as entries
        on entries.race_id = pace.race_id and entries.driver_id = pace.driver_id
    where pace.green_laps >= 10
),

race_pace as (
    select
        a.race_id, a.constructor_id, a.driver_id, b.driver_id as teammate_id,
        100.0 * (a.median_green_lap_ms - b.median_green_lap_ms)
            / ((a.median_green_lap_ms + b.median_green_lap_ms) / 2) as race_pace_delta_pct
    from pace as a
    inner join pace as b
        on a.race_id = b.race_id
        and a.constructor_id = b.constructor_id
        and a.driver_id <> b.driver_id
),

joined as (
    select
        coalesce(q.race_id, p.race_id) as race_id,
        coalesce(q.constructor_id, p.constructor_id) as constructor_id,
        coalesce(q.driver_id, p.driver_id) as driver_id,
        coalesce(q.teammate_id, p.teammate_id) as teammate_id,
        q.qual_session,
        iff(abs(q.qual_delta_pct) <= {{ max_abs_delta }}, q.qual_delta_pct, null) as qual_delta_pct,
        iff(abs(p.race_pace_delta_pct) <= {{ max_abs_delta }}, p.race_pace_delta_pct, null) as race_pace_delta_pct
    from qualifying as q
    full outer join race_pace as p
        on q.race_id = p.race_id
        and q.constructor_id = p.constructor_id
        and q.driver_id = p.driver_id
        and q.teammate_id = p.teammate_id
)

select
    races.season,
    joined.race_id,
    joined.constructor_id,
    joined.driver_id,
    joined.teammate_id,
    joined.qual_session,
    joined.qual_delta_pct,
    joined.race_pace_delta_pct
from joined
inner join {{ ref('stg_f1__races') }} as races on races.race_id = joined.race_id
where joined.qual_delta_pct is not null or joined.race_pace_delta_pct is not null
