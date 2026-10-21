-- Grain: one row per season, constructor, driver and teammate (both orderings).
with race_entries as (
    select
        season,
        race_id,
        constructor_id,
        driver_id,
        min(position_order) as best_position_order
    from {{ ref('fct_results') }}
    group by 1, 2, 3, 4
),

race_pairs as (
    select
        a.season,
        a.constructor_id,
        a.driver_id,
        b.driver_id as teammate_id,
        a.race_id,
        a.best_position_order < b.best_position_order as ahead
    from race_entries as a
    inner join race_entries as b
        on a.race_id = b.race_id
        and a.constructor_id = b.constructor_id
        and a.driver_id <> b.driver_id
),

race_summary as (
    select
        season,
        constructor_id,
        driver_id,
        teammate_id,
        count(distinct race_id)::integer as races_together,
        count(distinct case when ahead then race_id end)::integer as races_ahead
    from race_pairs
    group by 1, 2, 3, 4
),

quali_entries as (
    select
        races.season,
        qualifying.race_id,
        qualifying.constructor_id,
        qualifying.driver_id,
        min(qualifying.position) as best_position
    from {{ ref('stg_f1__qualifying') }} as qualifying
    inner join {{ ref('stg_f1__races') }} as races on races.race_id = qualifying.race_id
    group by 1, 2, 3, 4
),

quali_pairs as (
    select
        a.season,
        a.constructor_id,
        a.driver_id,
        b.driver_id as teammate_id,
        a.race_id,
        a.best_position < b.best_position as ahead
    from quali_entries as a
    inner join quali_entries as b
        on a.race_id = b.race_id
        and a.constructor_id = b.constructor_id
        and a.driver_id <> b.driver_id
),

quali_summary as (
    select
        season,
        constructor_id,
        driver_id,
        teammate_id,
        count(distinct race_id)::integer as qualifying_together,
        count(distinct case when ahead then race_id end)::integer as qualifying_ahead
    from quali_pairs
    group by 1, 2, 3, 4
)

select
    race_summary.season,
    race_summary.constructor_id,
    race_summary.driver_id,
    race_summary.teammate_id,
    race_summary.races_together,
    race_summary.races_ahead,
    coalesce(quali_summary.qualifying_together, 0)::integer as qualifying_together,
    coalesce(quali_summary.qualifying_ahead, 0)::integer as qualifying_ahead
from race_summary
left join quali_summary
    on quali_summary.season = race_summary.season
    and quali_summary.constructor_id = race_summary.constructor_id
    and quali_summary.driver_id = race_summary.driver_id
    and quali_summary.teammate_id = race_summary.teammate_id
