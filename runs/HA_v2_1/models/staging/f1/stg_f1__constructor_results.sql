select
    {{ clean_null('CONSTRUCTORRESULTSID') }}::int as constructor_results_id,
    {{ clean_null('RACEID') }}::int as race_id,
    {{ clean_null('CONSTRUCTORID') }}::int as constructor_id,
    {{ clean_null('POINTS') }}::decimal(6, 2) as points,
    {{ clean_null('STATUS') }} as status_text
from ({{ dedupe_raw(source('f1_raw', 'CONSTRUCTOR_RESULTS'), 'CONSTRUCTORRESULTSID') }})
