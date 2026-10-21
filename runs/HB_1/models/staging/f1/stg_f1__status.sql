with source as (

    select * from {{ source('f1_raw', 'status') }}

)

select
    cast(statusid as int) as status_id,
    {{ na_to_null('status') }} as status
from source
