-- The vendor has sent duplicate constructor rows. Each constructor_id must map to one row,
-- or every result joined to it is duplicated. The duplicate is reported by the source
-- unique test (warn), so this dedupe is visible rather than silent.

with source as (

    select * from {{ source('f1_raw', 'constructors') }}

)

select
    constructorid::integer as constructor_id,
    constructorref as constructor_ref,
    name as constructor_name,
    nationality
from source
qualify row_number() over (
    partition by constructorid
    order by constructorref, name, nationality, url
) = 1
