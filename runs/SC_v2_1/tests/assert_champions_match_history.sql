-- Official champions per the standings mart must equal real history, for every season
-- in the reference seed; and dim_drivers' championship totals must agree with it.
with from_mart as (

    select
        standings.season,
        drivers.driver_ref
    from {{ ref('mart_driver_season_standings') }} as standings
    inner join {{ ref('dim_drivers') }} as drivers on drivers.driver_id = standings.driver_id
    where standings.championship_position = 1
        and standings.is_season_complete

),

mismatches as (

    select coalesce(expected.season, from_mart.season) as season,
        expected.driver_ref as expected_driver_ref,
        from_mart.driver_ref as actual_driver_ref
    from {{ ref('ref_world_champions') }} as expected
    full outer join from_mart on from_mart.season = expected.season
    where expected.driver_ref is distinct from from_mart.driver_ref

)

select * from mismatches
