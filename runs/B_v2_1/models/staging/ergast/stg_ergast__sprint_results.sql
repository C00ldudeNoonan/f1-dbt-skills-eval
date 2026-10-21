with cleaned as (
    select
        {{ clean_int('resultid') }}                 as sprint_result_id,
        {{ clean_int('raceid') }}                   as race_id,
        {{ clean_int('driverid') }}                 as driver_id,
        {{ clean_int('constructorid') }}            as constructor_id,
        {{ clean_int('number') }}                   as car_number,
        {{ clean_int('grid') }}                     as grid,
        {{ clean_int('position') }}                 as finish_position,
        {{ clean_text('positiontext') }}            as position_text,
        {{ clean_int('position_order') }}            as position_order,
        {{ clean_decimal('points') }}               as points,
        {{ clean_int('laps') }}                     as laps,
        {{ clean_int('milliseconds') }}             as race_time_ms,
        {{ clean_int('fastestlap') }}               as fastest_lap_number,
        {{ lap_time_to_ms('fastestlaptime') }}      as fastest_lap_time_ms,
        {{ clean_int('statusid') }}                 as status_id
    from {{ source('ergast', 'sprint_results') }}
)

select * from cleaned
{{ dedupe('race_id, driver_id', 'sprint_result_id') }}
