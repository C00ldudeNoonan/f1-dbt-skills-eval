select
    {{ clean_null('CONSTRUCTORID') }}::int as constructor_id,
    {{ clean_null('CONSTRUCTORREF') }} as constructor_ref,
    {{ clean_null('NAME') }} as constructor_name,
    {{ clean_null('NATIONALITY') }} as nationality
from ({{ dedupe_raw(source('f1_raw', 'CONSTRUCTORS'), 'CONSTRUCTORID') }})
