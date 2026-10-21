with cleaned as (
    select
        {{ clean_int('constructorresultsid') }} as constructor_result_id,
        {{ clean_int('raceid') }}               as race_id,
        {{ clean_int('constructorid') }}        as constructor_id,
        {{ clean_decimal('points') }}           as points,
        {{ clean_text('status') }}              as status
    from {{ source('ergast', 'constructor_results') }}
)

select * from cleaned
{{ dedupe('race_id, constructor_id', 'constructor_result_id') }}
