{#
    One row per driver per comparison with a teammate in the same race, for two measures:
      - race_finish: both drivers classified in the race. Finishing position.
      - qualifying: both drivers in the qualifying session. Qualifying position.
    positions_gained is the teammate's position minus the driver's, so positive means the driver finished (or qualified)
    ahead. Each comparison appears once for each driver, so a row and its mirror image sum to zero.

    Both measures use only entries where the teammate is also present. A retirement is not counted as a
    comparison for the race measure, because a DNF reflects reliability more than the driver.
#}
with race_entries as (

    select
        race_id,
        season,
        constructor_id,
        driver_id,
        min(finish_position) as position
    from {{ ref('fct_results') }}
    where finish_position is not null
    group by race_id, season, constructor_id, driver_id

),

quali_entries as (

    select
        race_id,
        season,
        constructor_id,
        driver_id,
        min(qualifying_position) as position
    from {{ ref('fct_qualifying') }}
    group by race_id, season, constructor_id, driver_id

),

race_pairs as (

    select
        'race_finish' as measure,
        driver.race_id,
        driver.season,
        driver.constructor_id,
        driver.driver_id,
        teammate.driver_id as teammate_id,
        driver.position as driver_position,
        teammate.position as teammate_position
    from race_entries as driver
    inner join race_entries as teammate
        on driver.race_id = teammate.race_id
        and driver.constructor_id = teammate.constructor_id
        and driver.driver_id <> teammate.driver_id

),

quali_pairs as (

    select
        'qualifying' as measure,
        driver.race_id,
        driver.season,
        driver.constructor_id,
        driver.driver_id,
        teammate.driver_id as teammate_id,
        driver.position as driver_position,
        teammate.position as teammate_position
    from quali_entries as driver
    inner join quali_entries as teammate
        on driver.race_id = teammate.race_id
        and driver.constructor_id = teammate.constructor_id
        and driver.driver_id <> teammate.driver_id

)

select
    *,
    teammate_position - driver_position as positions_gained
from race_pairs

union all

select
    *,
    teammate_position - driver_position as positions_gained
from quali_pairs
