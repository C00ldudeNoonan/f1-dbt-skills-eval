with source as (
    select * from {{ source('f1_raw', 'drivers') }}
),

cleaned as (
    select
        {{ to_integer('driverid') }} as driver_id,
        {{ clean_text('driverref') }} as driver_ref,
        {{ to_integer('number') }} as permanent_number,
        {{ clean_text('code') }} as driver_code,
        {{ clean_text('forename') }} as forename,
        {{ clean_text('surname') }} as surname,
        try_to_date({{ clean_text('dob') }}, 'YYYY-MM-DD') as date_of_birth,
        {{ clean_text('nationality') }} as raw_nationality,
        {{ clean_text('url') }} as wikipedia_url
    from source
)

select
    driver_id,
    driver_ref,
    permanent_number,
    driver_code,
    forename,
    surname,
    forename || ' ' || surname as full_name,
    date_of_birth,
    -- One recent driver is loaded as 'Argentinian'; every other Argentine
    -- driver uses the Ergast demonym 'Argentine'.
    case raw_nationality
        when 'Argentinian' then 'Argentine'
        else raw_nationality
    end as nationality,
    wikipedia_url
from cleaned
{{ deduplicate('driver_id', 'driver_id') }}
