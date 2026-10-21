with source as (

    select * from {{ source('f1_raw', 'results') }}

),

renamed as (

    select
        resultid::integer as result_id,
        raceid::integer as race_id,
        driverid::integer as driver_id,
        constructorid::integer as constructor_id,
        statusid::integer as status_id,
        grid::integer as grid,
        {{ finish_position('position', 'positiontext') }} as finish_position,
        position_order::integer as position_order,
        points::number(8, 2) as points,
        laps::integer as laps,
        {{ time_text_to_ms('fastestlaptime') }} as fastest_lap_time_ms
    from source

)

select * from renamed
{{ dedupe(['result_id']) }}
