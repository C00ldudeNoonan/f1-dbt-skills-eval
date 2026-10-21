with source as (

    select * from {{ source('f1_raw', 'sprint_results') }}

)

select
    cast(resultid as int) as sprint_result_id,
    cast(raceid as int) as race_id,
    cast(driverid as int) as driver_id,
    cast(constructorid as int) as constructor_id,
    cast({{ na_to_null('grid') }} as int) as grid,
    cast({{ na_to_null('position') }} as int) as finish_position,
    cast(position_order as int) as position_order,
    cast(points as decimal(6, 2)) as points,
    cast({{ na_to_null('laps') }} as int) as laps,
    cast(statusid as int) as status_id
from source
