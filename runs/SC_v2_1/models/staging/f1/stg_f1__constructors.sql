select
    constructorid::integer as constructor_id,
    trim(constructorref) as constructor_ref,
    trim(name) as constructor_name,
    {{ clean_raw('nationality') }} as nationality
from {{ source('f1_raw', 'constructors') }}
{{ dedupe(['constructor_id']) }}
