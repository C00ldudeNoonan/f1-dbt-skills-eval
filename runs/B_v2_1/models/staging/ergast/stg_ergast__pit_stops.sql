with cleaned as (
    select
        {{ clean_int('raceid') }}       as race_id,
        {{ clean_int('driverid') }}     as driver_id,
        {{ clean_int('stop') }}         as stop_number,
        {{ clean_int('lap') }}          as lap,
        {{ clean_text('time') }}        as time_of_day,
        -- The vendor dropped the redundant DURATION text column on 2026-10-21; MILLISECONDS is the value.
        {{ clean_int('milliseconds') }} as duration_ms
    from {{ source('ergast', 'pit_stops') }}
)

select * from cleaned
{{ dedupe('race_id, driver_id, stop_number', 'duration_ms') }}
