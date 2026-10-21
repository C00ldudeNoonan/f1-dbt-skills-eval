with source as (

    select * from {{ source('f1_raw', 'results') }}

),

renamed as (

    select
        {{ clean_null('resultid') }}::integer as result_id,
        {{ clean_null('raceid') }}::integer as race_id,
        {{ clean_null('driverid') }}::integer as driver_id,
        {{ clean_null('constructorid') }}::integer as constructor_id,
        {{ clean_null('grid') }}::integer as grid,
        {{ clean_null('position') }}::integer as position,
        {{ clean_null('positiontext') }} as position_text,
        {{ clean_null('position_order') }}::integer as position_order,
        {{ clean_null('points') }}::float as points,
        {{ clean_null('laps') }}::integer as laps,
        {{ clean_null('milliseconds') }}::integer as race_time_ms,
        {{ clean_null('fastestlap') }}::integer as fastest_lap_number,
        {{ lap_time_to_ms(clean_null('fastestlaptime')) }} as fastest_lap_time_ms,
        {{ clean_null('statusid') }}::integer as status_id

    from source

)

select * from renamed
