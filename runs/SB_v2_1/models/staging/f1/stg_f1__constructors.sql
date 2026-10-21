select
    {{ clean_int('constructorid') }} as constructor_id,
    {{ clean_raw('constructorref') }} as constructor_ref,
    {{ clean_raw('name') }} as constructor_name,
    {{ clean_raw('nationality') }} as nationality
from {{ source('f1_raw', 'constructors') }}
qualify row_number() over (partition by constructor_id order by constructor_id) = 1
