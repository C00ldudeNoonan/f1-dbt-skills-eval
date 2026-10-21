with source as (
    select * from {{ source('ergast', 'constructors') }}
)

-- distinct on the *cleaned* values: a repeated vendor load (even one that differs
-- only in whitespace) collapses to one row. Duplicate keys with genuinely
-- different values survive and fail this model's unique test (see README).
select distinct
    {{ ergast_int('constructorid') }}       as constructor_id,
    {{ ergast_clean('constructorref') }}    as constructor_ref,
    {{ ergast_clean('name') }}              as constructor_name,
    {{ ergast_clean('nationality') }}       as nationality,
    {{ ergast_clean('url') }}               as wikipedia_url
from source
