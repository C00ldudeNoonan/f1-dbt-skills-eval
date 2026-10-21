with cleaned as (
    select
        {{ clean_int('raceid') }}       as race_id,
        {{ clean_int('driverid') }}     as driver_id,
        {{ clean_int('lap') }}          as lap,
        {{ clean_int('position') }}     as position,
        {{ clean_int('milliseconds') }} as lap_time_ms
    from {{ source('ergast', 'lap_times') }}
)

select * from cleaned
{{ dedupe('race_id, driver_id, lap', 'lap_time_ms') }}
