with source as (

    select * from {{ source('ergast', 'races') }}

)

select
    try_to_number(raceid) as race_id,
    try_to_number(year) as season,
    try_to_number(round) as round,
    try_to_number(circuitid) as circuit_id,
    name as race_name,
    try_to_date(date) as race_date

from source
