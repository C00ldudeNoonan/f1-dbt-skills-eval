{#
    The 2026-10-21 feed loaded the round 22 standings of 2024 twice, under two standings ids
    with identical values. Keep one row per race and driver. The qualify below is safe only
    because tests/assert_no_conflicting_duplicate_copies.sql fails the build when copies differ.
#}
with source as (

    select
        {{ clean_null('driverstandingsid') }}::integer as driver_standings_id,
        {{ clean_null('raceid') }}::integer as race_id,
        {{ clean_null('driverid') }}::integer as driver_id,
        {{ clean_null('points') }}::float as points,
        {{ clean_null('position') }}::integer as position,
        {{ clean_null('positiontext') }} as position_text,
        {{ clean_null('wins') }}::integer as wins

    from {{ source('f1_raw', 'driver_standings') }}

)

select *
from source
qualify row_number() over (partition by race_id, driver_id order by driver_standings_id) = 1
