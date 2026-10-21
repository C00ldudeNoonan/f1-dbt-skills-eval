-- Qualifying entries with the constructor the driver raced for. The source
-- sometimes records a team under a different constructor id in qualifying
-- than in results (Marussia / Manor Marussia, 2015), so the race constructor
-- wins where the driver raced for exactly one constructor in that Grand Prix.

with qualifying as (
    select * from {{ ref('fct_qualifying') }}
),

results as (
    select * from {{ ref('fct_results') }}
),

single_constructor_entries as (
    select
        race_id,
        driver_id,
        min(constructor_id) as constructor_id
    from results
    group by race_id, driver_id
    having count(distinct constructor_id) = 1
)

select
    qualifying.qualify_id,
    qualifying.race_id,
    qualifying.season,
    qualifying.round,
    qualifying.driver_id,
    coalesce(race_constructor.constructor_id, qualifying.constructor_id) as constructor_id,
    qualifying.qualifying_position,
    qualifying.q1_ms,
    qualifying.q2_ms,
    qualifying.q3_ms
from qualifying
left join single_constructor_entries as race_constructor
    on qualifying.race_id = race_constructor.race_id
    and qualifying.driver_id = race_constructor.driver_id
