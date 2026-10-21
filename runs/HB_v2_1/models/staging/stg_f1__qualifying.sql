with source as (

    select * from {{ source('f1_raw', 'qualifying') }}

),

cleaned as (

    select
        {{ clean_null('qualifyid') }}::integer as qualify_id,
        {{ clean_null('raceid') }}::integer as race_id,
        {{ clean_null('driverid') }}::integer as driver_id,
        {{ clean_null('constructorid') }}::integer as constructor_id,
        {{ clean_null('position') }}::integer as position,
        {{ clean_null('q1') }} as q1_text,
        {{ clean_null('q2') }} as q2_text,
        {{ clean_null('q3') }} as q3_text

    from source

)

select
    qualify_id,
    race_id,
    driver_id,
    constructor_id,
    position,
    {{ lap_time_to_ms('q1_text') }} as q1_ms,
    {{ lap_time_to_ms('q2_text') }} as q2_ms,
    {{ lap_time_to_ms('q3_text') }} as q3_ms

from cleaned
