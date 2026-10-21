with source as (
    select * from {{ source('ergast', 'status') }}
)

-- distinct on the *cleaned* values: a repeated vendor load (even one that differs
-- only in whitespace) collapses to one row. Duplicate keys with genuinely
-- different values survive and fail this model's unique test (see README).
select distinct
    {{ ergast_int('statusid') }}    as status_id,
    {{ ergast_clean('status') }}    as status
from source
