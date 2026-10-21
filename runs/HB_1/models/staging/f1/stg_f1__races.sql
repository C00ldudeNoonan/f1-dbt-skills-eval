with source as (

    select * from {{ source('f1_raw', 'races') }}

)

select
    cast(raceid as int) as race_id,
    cast(year as int) as season,
    cast(round as int) as round,
    cast(circuitid as int) as circuit_id,
    {{ na_to_null('name') }} as race_name,
    cast({{ na_to_null('date') }} as date) as race_date
from source
