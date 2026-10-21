with source as (

    select * from {{ source('f1_raw', 'races') }}

),

renamed as (

    select
        {{ clean_null('raceid') }}::integer as race_id,
        {{ clean_null('year') }}::integer as season,
        {{ clean_null('round') }}::integer as round,
        {{ clean_null('name') }} as race_name,
        -- The 2026-10-21 migration changed race dates from ISO to dd/mm/yyyy.
        try_to_date({{ clean_null('date') }}, 'DD/MM/YYYY') as race_date,
        coalesce(
            try_to_date({{ clean_null('sprint_date') }}, 'YYYY-MM-DD'),
            try_to_date({{ clean_null('sprint_date') }}, 'DD/MM/YYYY')
        ) as sprint_date,
        {{ clean_null('circuitid') }}::integer as circuit_id

    from source

)

select * from renamed
