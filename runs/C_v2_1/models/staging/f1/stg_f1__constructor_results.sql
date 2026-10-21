with source as (
    select * from {{ source('f1_raw', 'constructor_results') }}
)

select
    {{ to_integer('constructorresultsid') }} as constructor_results_id,
    {{ to_integer('raceid') }} as race_id,
    {{ to_integer('constructorid') }} as constructor_id,
    {{ to_decimal('points', 8, 2) }} as points,
    -- 'D' on McLaren's 2007 rows (excluded from the constructors' championship), otherwise null.
    {{ clean_text('status') }} as status
from source
{{ deduplicate('race_id, constructor_id', 'constructor_results_id') }}
