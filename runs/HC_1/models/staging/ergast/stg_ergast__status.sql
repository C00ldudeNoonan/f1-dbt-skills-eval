with source as (

    select * from {{ source('ergast', 'status') }}

)

select
    try_to_number(statusid) as status_id,
    status

from source
