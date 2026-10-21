select
    {{ to_int('constructorid') }} as constructor_id,
    {{ clean_text('constructorref') }} as constructor_ref,
    {{ clean_text('name') }} as constructor_name,
    {{ clean_text('nationality') }} as nationality,
    {{ clean_text('url') }} as url
from {{ source('ergast', 'constructors') }}
-- One row per natural key, so a duplicated raw row can't fan out downstream joins.
{{ dedupe_on(['constructor_id'], 'constructor_id') }}
