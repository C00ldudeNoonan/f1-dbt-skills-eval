with results as (

    select * from {{ ref('fct_results') }}

),

qualifying as (

    select
        qualifying.race_id,
        qualifying.constructor_id,
        qualifying.driver_id,
        races.season,
        min(qualifying.qualifying_position) as best_qualifying_position
    from {{ ref('fct_qualifying') }} as qualifying
    inner join {{ ref('stg_f1__races') }} as races on races.race_id = qualifying.race_id
    group by all

),

-- one row per driver per constructor per race; shared drives can repeat a driver
race_entries as (

    select
        season,
        race_id,
        constructor_id,
        driver_id,
        min(position_order) as best_position_order
    from results
    group by all

),

race_pairs as (

    select
        a.season,
        a.constructor_id,
        a.driver_id,
        b.driver_id as teammate_id,
        count(*)::integer as races_together,
        count_if(a.best_position_order < b.best_position_order)::integer as races_ahead
    from race_entries as a
    inner join race_entries as b
        on a.race_id = b.race_id
        and a.constructor_id = b.constructor_id
        and a.driver_id <> b.driver_id
    group by all

),

qualifying_pairs as (

    select
        a.season,
        a.constructor_id,
        a.driver_id,
        b.driver_id as teammate_id,
        count(*)::integer as qualifying_together,
        count_if(a.best_qualifying_position < b.best_qualifying_position)::integer as qualifying_ahead
    from qualifying as a
    inner join qualifying as b
        on a.race_id = b.race_id
        and a.constructor_id = b.constructor_id
        and a.driver_id <> b.driver_id
    group by all

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
    on qualifying_pairs.season = race_pairs.season
    and qualifying_pairs.constructor_id = race_pairs.constructor_id
    and qualifying_pairs.driver_id = race_pairs.driver_id
    and qualifying_pairs.teammate_id = race_pairs.teammate_id
