-- Vendor B names are `SURNAME Firstname`: the surname is everything before the first
-- capitalised-lowercase word.
with source as (

    select * from {{ source('f1_raw', 'vb_drivers') }}

),

parsed as (

    select
        trim(driver_key) as driver_key,
        trim(full_name) as full_name,
        regexp_instr(trim(full_name), '[A-Z][a-z]') as first_name_pos,
        {{ clean_raw('abbreviation') }} as driver_code,
        try_to_number({{ clean_raw('racing_number') }})::integer as racing_number
    from source

)

select
    driver_key,
    full_name,
    case when first_name_pos > 0 then trim(left(full_name, first_name_pos - 1)) else full_name end as surname,
    case when first_name_pos > 0 then trim(substr(full_name, first_name_pos)) end as first_name,
    driver_code,
    racing_number
from parsed
{{ dedupe(['driver_key']) }}
