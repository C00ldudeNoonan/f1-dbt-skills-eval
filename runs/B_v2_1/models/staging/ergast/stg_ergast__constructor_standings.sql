with cleaned as (
    select
        {{ clean_int('constructorstandingsid') }}   as constructor_standing_id,
        {{ clean_int('raceid') }}                   as race_id,
        {{ clean_int('constructorid') }}            as constructor_id,
        {{ clean_decimal('points') }}               as points,
        {{ clean_int('position') }}                 as position,
        {{ clean_text('positiontext') }}            as position_text,
        {{ clean_int('wins') }}                     as wins
    from {{ source('ergast', 'constructor_standings') }}
)

select * from cleaned
{{ dedupe('race_id, constructor_id', 'constructor_standing_id') }}
