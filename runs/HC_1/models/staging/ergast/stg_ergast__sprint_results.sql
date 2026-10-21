with source as (

    select * from {{ source('ergast', 'sprint_results') }}

)

select
    try_to_number(resultid) as sprint_result_id,
    try_to_number(raceid) as race_id,
    try_to_number(driverid) as driver_id,
    try_to_number(constructorid) as constructor_id,
    {{ classified_position('position', 'positiontext') }} as finish_position,
    try_to_decimal(points, 6, 2) as points,
    try_to_number(laps) as laps,
    try_to_number(statusid) as status_id

from source
