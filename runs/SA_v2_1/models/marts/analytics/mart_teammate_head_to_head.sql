-- Both orderings of every teammate pair, per season and constructor.
-- "Ahead" compares each driver's best position_order (race) or qualifying position
-- in the Grands Prix where both have an entry for that constructor; ties are not ahead.
with race_entries as (

    select
        season,
        constructor_id,
        race_id,
        driver_id,
        min(position_order) as best_position_order
    from {{ ref('fct_results') }}
    group by season, constructor_id, race_id, driver_id

),

race_pairs as (

    select
        a.season,
        a.constructor_id,
        a.driver_id,
        b.driver_id as teammate_id,
        count(distinct a.race_id) as races_together,
        count(distinct case when a.best_position_order < b.best_position_order then a.race_id end) as races_ahead
    from race_entries as a
    inner join race_entries as b
        on a.race_id = b.race_id
        and a.constructor_id = b.constructor_id
        and a.driver_id <> b.driver_id
    group by a.season, a.constructor_id, a.driver_id, b.driver_id

),

qualifying_entries as (

    select
        races.season,
        qualifying.constructor_id,
        qualifying.race_id,
        qualifying.driver_id,
        min(qualifying.qualifying_position) as best_qualifying_position
    from {{ ref('fct_qualifying') }} as qualifying
    inner join {{ ref('stg_ergast__races') }} as races on qualifying.race_id = races.race_id
    group by races.season, qualifying.constructor_id, qualifying.race_id, qualifying.driver_id

),

qualifying_pairs as (

    select
        a.season,
        a.constructor_id,
        a.driver_id,
        b.driver_id as teammate_id,
        count(distinct a.race_id) as qualifying_together,
        count(distinct case when a.best_qualifying_position < b.best_qualifying_position then a.race_id end) as qualifying_ahead
    from qualifying_entries as a
    inner join qualifying_entries as b
        on a.race_id = b.race_id
        and a.constructor_id = b.constructor_id
        and a.driver_id <> b.driver_id
    group by a.season, a.constructor_id, a.driver_id, b.driver_id

)

select
    race_pairs.season,
    race_pairs.constructor_id,
    race_pairs.driver_id,
    race_pairs.teammate_id,
    race_pairs.races_together,
    race_pairs.races_ahead,
    coalesce(qualifying_pairs.qualifying_together, 0) as qualifying_together,
    coalesce(qualifying_pairs.qualifying_ahead, 0) as qualifying_ahead
from race_pairs
left join qualifying_pairs
    on race_pairs.season = qualifying_pairs.season
    and race_pairs.constructor_id = qualifying_pairs.constructor_id
    and race_pairs.driver_id = qualifying_pairs.driver_id
    and race_pairs.teammate_id = qualifying_pairs.teammate_id
