with source as (

    select * from {{ source('f1_raw', 'results') }}

)

select
    cast(resultid as int) as result_id,
    cast(raceid as int) as race_id,
    cast(driverid as int) as driver_id,
    cast(constructorid as int) as constructor_id,
    cast({{ na_to_null('grid') }} as int) as grid,
    -- position is null exactly when the entry was not classified (R, D, W, N, E, F)
    cast({{ na_to_null('position') }} as int) as finish_position,
    {{ na_to_null('positiontext') }} as finish_position_text,
    cast(position_order as int) as position_order,
    cast(points as decimal(6, 2)) as points,
    cast({{ na_to_null('laps') }} as int) as laps,
    cast(statusid as int) as status_id,
    {{ na_to_null('fastestlaptime') }} as fastest_lap_time_text
from source
