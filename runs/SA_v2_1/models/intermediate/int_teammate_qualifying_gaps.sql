-- One row per ordered teammate pair per race with both best qualifying times: the driver's best time
-- relative to the teammate's, in percent (negative = faster than the teammate). Same car, same
-- session, so car and track effects cancel. Gaps beyond +/-5% are dropped (crashes, red flags,
-- mechanical trouble, wet/dry mismatches: not driver speed).
with entries as (

    select
        qualifying.race_id,
        races.season,
        qualifying.constructor_id,
        qualifying.driver_id,
        min(qualifying.best_time_ms) as best_time_ms
    from {{ ref('fct_qualifying') }} as qualifying
    inner join {{ ref('stg_ergast__races') }} as races on qualifying.race_id = races.race_id
    where qualifying.best_time_ms is not null
    group by qualifying.race_id, races.season, qualifying.constructor_id, qualifying.driver_id

)

select
    a.season,
    a.race_id,
    a.constructor_id,
    a.driver_id,
    b.driver_id as teammate_id,
    100.0 * (a.best_time_ms - b.best_time_ms) / b.best_time_ms as gap_pct
from entries as a
inner join entries as b
    on a.race_id = b.race_id
    and a.constructor_id = b.constructor_id
    and a.driver_id <> b.driver_id
where abs(100.0 * (a.best_time_ms - b.best_time_ms) / b.best_time_ms) <= 5
