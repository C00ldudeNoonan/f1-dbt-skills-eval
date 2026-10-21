{#-
  Grand Prix results only (sprints are in stg_ergast__sprint_results).
-#}
with cleaned as (
    select
        {{ clean_int('resultid') }}                 as result_id,
        {{ clean_int('raceid') }}                   as race_id,
        {{ clean_int('driverid') }}                 as driver_id,
        {{ clean_int('constructorid') }}            as constructor_id,
        {{ clean_int('number') }}                   as car_number,
        -- 0 means the car started from the pit lane (or the grid slot is unknown).
        {{ clean_int('grid') }}                     as grid,
        -- POSITION is null for unclassified entries. Two classified finishers in race 71
        -- (2005 Australian GP) have POSITION '\N' but a numeric POSITIONTEXT, so fall back
        -- to POSITIONTEXT when it is purely digits. Letters (R, D, E, W, F, N) stay null.
        coalesce(
            {{ clean_int('position') }},
            iff(regexp_like({{ clean_text('positiontext') }}, '^[0-9]+$'), {{ clean_text('positiontext') }}::integer, null)
        )                                           as finish_position,
        {{ clean_text('positiontext') }}            as position_text,
        {{ clean_int('position_order') }}            as position_order,
        {{ clean_decimal('points') }}               as points,
        {{ clean_int('laps') }}                     as laps,
        {{ clean_int('milliseconds') }}             as race_time_ms,
        {{ clean_int('fastestlap') }}               as fastest_lap_number,
        {{ clean_int('rank') }}                     as fastest_lap_rank,
        {{ lap_time_to_ms('fastestlaptime') }}      as fastest_lap_time_ms,
        try_to_double({{ clean_text('fastestlapspeed') }}) as fastest_lap_speed_kph,
        {{ clean_int('statusid') }}                 as status_id
    from {{ source('ergast', 'results') }}
)

select * from cleaned
{{ dedupe('race_id, driver_id, position_order', 'result_id') }}
