with source as (

    select * from {{ source('ergast', 'results') }}

)

select
    try_to_number(resultid) as result_id,
    try_to_number(raceid) as race_id,
    try_to_number(driverid) as driver_id,
    try_to_number(constructorid) as constructor_id,
    try_to_number({{ null_if_sentinel('grid') }}) as grid,
    {{ classified_position('position', 'positiontext') }} as finish_position,
    {{ null_if_sentinel('positiontext') }} as finish_position_text,
    try_to_number(position_order) as position_order,
    try_to_decimal(points, 6, 2) as points,
    try_to_number(laps) as laps,
    try_to_number(statusid) as status_id,
    {{ lap_time_to_ms(null_if_sentinel('fastestlaptime')) }} as fastest_lap_time_ms

from source
