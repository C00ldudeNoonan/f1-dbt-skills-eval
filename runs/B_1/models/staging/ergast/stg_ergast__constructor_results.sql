with source as (
    select * from {{ source('ergast', 'constructor_results') }}
)

-- distinct on the *cleaned* values: a repeated vendor load (even one that differs
-- only in whitespace) collapses to one row. Duplicate keys with genuinely
-- different values survive and fail this model's unique test (see README).
select distinct
    {{ ergast_int('constructorresultsid') }}    as constructor_result_id,
    {{ ergast_int('raceid') }}                  as race_id,
    {{ ergast_int('constructorid') }}           as constructor_id,
    {{ ergast_number('points') }}               as points,
    {{ ergast_clean('status') }}                as status
from source
