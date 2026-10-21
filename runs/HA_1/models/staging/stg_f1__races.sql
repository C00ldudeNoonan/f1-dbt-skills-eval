with source as (

    select * from {{ source('f1_raw', 'races') }}

)

select
    raceid::integer as race_id,
    year::integer as season,
    round::integer as round,
    circuitid::integer as circuit_id,
    name as race_name,
    {{ null_marker('date') }}::date as race_date
from source
