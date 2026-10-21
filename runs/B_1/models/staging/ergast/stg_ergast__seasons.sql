with source as (
    select * from {{ source('ergast', 'seasons') }}
)

-- distinct on the *cleaned* values: a repeated vendor load (even one that differs
-- only in whitespace) collapses to one row. Duplicate keys with genuinely
-- different values survive and fail this model's unique test (see README).
select distinct
    {{ ergast_int('year') }}    as season,
    {{ ergast_clean('url') }}   as wikipedia_url
from source
