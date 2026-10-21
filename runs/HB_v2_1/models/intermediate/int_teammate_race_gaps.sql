{#
    One row per driver per race where that driver and a teammate (same constructor, same Grand
    Prix) were both classified. Both orderings appear, so each driver has their own rows.

    race_gap is teammate finish minus driver finish: positive means the driver finished ahead.
    quali_gap is the same for qualifying positions, where both have a position.

    Limited to 1981 onward. Before then, shared cars and repeated driver pairs make a teammate
    comparison unreliable (see the README).
#}
with results as (

    select
        race_id,
        season,
        constructor_id,
        driver_id,
        finish_position

    from {{ ref('fct_results') }}
    where season >= 1981
        and finish_position is not null

),

qualifying as (

    select
        race_id,
        constructor_id,
        driver_id,
        position

    from {{ ref('fct_qualifying') }}
    where season >= 1981

)

select
    driver.season,
    driver.race_id,
    driver.constructor_id,
    driver.driver_id,
    teammate.driver_id as teammate_id,
    teammate.finish_position - driver.finish_position as race_gap,
    teammate_quali.position - driver_quali.position as quali_gap

from results as driver
inner join results as teammate
    on driver.race_id = teammate.race_id
    and driver.constructor_id = teammate.constructor_id
    and driver.driver_id <> teammate.driver_id
left join qualifying as driver_quali
    on driver.race_id = driver_quali.race_id
    and driver.driver_id = driver_quali.driver_id
    and driver.constructor_id = driver_quali.constructor_id
left join qualifying as teammate_quali
    on teammate.race_id = teammate_quali.race_id
    and teammate.driver_id = teammate_quali.driver_id
    and teammate.constructor_id = teammate_quali.constructor_id
