{#
    Grain: one row per season, constructor, driver and teammate. Both orderings exist
    (A vs B and B vs A). A pair is any two drivers who had a Grand Prix result for the
    same constructor in the same race at least once.
      - races_together: Grands Prix where both had a result for that constructor.
      - races_ahead: of those, races where this driver's best position_order beat the
        teammate's best. Ties do not count as ahead.
      - qualifying_together: Grands Prix where both had a qualifying entry for that
        constructor (regardless of whether both raced).
      - qualifying_ahead: of those, races where this driver's qualifying position was
        better (lower) than the teammate's.
#}
with race_entries as (

    select
        season,
        race_id,
        constructor_id,
        driver_id,
        min(position_order) as best_position_order
    from {{ ref('fct_results') }}
    group by season, race_id, constructor_id, driver_id

),

race_pairs as (

    select
        driver.season,
        driver.constructor_id,
        driver.driver_id,
        teammate.driver_id as teammate_id,
        driver.race_id,
        driver.best_position_order < teammate.best_position_order as is_ahead
    from race_entries as driver
    inner join race_entries as teammate
        on driver.race_id = teammate.race_id
        and driver.constructor_id = teammate.constructor_id
        and driver.driver_id <> teammate.driver_id

),

race_pair_totals as (

    select
        season,
        constructor_id,
        driver_id,
        teammate_id,
        count(distinct race_id) as races_together,
        count(distinct case when is_ahead then race_id end) as races_ahead
    from race_pairs
    group by season, constructor_id, driver_id, teammate_id

),

quali_pairs as (

    select
        driver.season,
        driver.constructor_id,
        driver.driver_id,
        teammate.driver_id as teammate_id,
        driver.race_id,
        driver.qualifying_position < teammate.qualifying_position as is_ahead
    from {{ ref('fct_qualifying') }} as driver
    inner join {{ ref('fct_qualifying') }} as teammate
        on driver.race_id = teammate.race_id
        and driver.constructor_id = teammate.constructor_id
        and driver.driver_id <> teammate.driver_id
    where driver.qualifying_position is not null
        and teammate.qualifying_position is not null

),

quali_pair_totals as (

    select
        season,
        constructor_id,
        driver_id,
        teammate_id,
        count(distinct race_id) as qualifying_together,
        count(distinct case when is_ahead then race_id end) as qualifying_ahead
    from quali_pairs
    group by season, constructor_id, driver_id, teammate_id

)

select
    race_pair_totals.season,
    race_pair_totals.constructor_id,
    race_pair_totals.driver_id,
    race_pair_totals.teammate_id,
    race_pair_totals.races_together,
    race_pair_totals.races_ahead,
    coalesce(quali_pair_totals.qualifying_together, 0) as qualifying_together,
    coalesce(quali_pair_totals.qualifying_ahead, 0) as qualifying_ahead
from race_pair_totals
left join quali_pair_totals
    on race_pair_totals.season = quali_pair_totals.season
    and race_pair_totals.constructor_id = quali_pair_totals.constructor_id
    and race_pair_totals.driver_id = quali_pair_totals.driver_id
    and race_pair_totals.teammate_id = quali_pair_totals.teammate_id
