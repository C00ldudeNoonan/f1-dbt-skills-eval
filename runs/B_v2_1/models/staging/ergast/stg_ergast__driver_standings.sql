with cleaned as (
    select
        {{ clean_int('driverstandingsid') }}    as driver_standing_id,
        {{ clean_int('raceid') }}               as race_id,
        {{ clean_int('driverid') }}             as driver_id,
        {{ clean_decimal('points') }}           as points,
        -- POSITION is always populated, but POSITIONTEXT 'D' marks a driver excluded
        -- from the championship (Schumacher 1997). Keep the raw rank and the flag.
        {{ clean_int('position') }}             as position,
        {{ clean_text('positiontext') }}        as position_text,
        {{ clean_text('positiontext') }} = 'D'  as is_excluded,
        {{ clean_int('wins') }}                 as wins
    from {{ source('ergast', 'driver_standings') }}
)

select * from cleaned
{{ dedupe('race_id, driver_id', 'driver_standing_id') }}
