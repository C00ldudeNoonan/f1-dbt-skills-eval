with source as (

    select * from {{ source('f1_raw', 'status') }}

)

select
    statusid::integer as status_id,
    status
from source
