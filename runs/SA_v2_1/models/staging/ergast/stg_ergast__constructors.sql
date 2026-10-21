-- `select distinct` after cleaning collapses exact re-deliveries by the vendor (e.g. the same
-- constructor sent twice, once with a trailing space in its name). Conflicting duplicates are
-- not collapsed and fail the unique test on constructor_id.
select distinct
    constructorid::integer as constructor_id,
    {{ clean_text('constructorref') }} as constructor_ref,
    {{ clean_text('name') }} as constructor_name,
    {{ clean_text('nationality') }} as nationality
from {{ source('ergast', 'constructors') }}
