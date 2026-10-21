with cleaned as (
    select
        {{ clean_int('qualifyid') }}        as qualify_id,
        {{ clean_int('raceid') }}           as race_id,
        {{ clean_int('driverid') }}         as driver_id,
        {{ clean_int('constructorid') }}    as constructor_id,
        {{ clean_int('number') }}           as car_number,
        {{ clean_int('position') }}         as qualifying_position,
        {{ lap_time_to_ms('q1') }}          as q1_ms,
        {{ lap_time_to_ms('q2') }}          as q2_ms,
        {{ lap_time_to_ms('q3') }}          as q3_ms
    from {{ source('ergast', 'qualifying') }}
)

select * from cleaned
{{ dedupe('race_id, driver_id', 'qualify_id') }}
