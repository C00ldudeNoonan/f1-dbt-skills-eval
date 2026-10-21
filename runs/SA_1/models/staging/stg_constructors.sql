-- The vendor feed has delivered duplicate constructor rows that differ only by stray
-- whitespace (e.g. 'Ferrari' vs 'Ferrari '), which fanned out every join to constructors.
-- Trim text, then keep exactly one row per constructor_id.
select
    constructorid::int as constructor_id,
    trim(constructorref) as constructor_ref,
    trim(name) as constructor_name,
    trim(nationality) as nationality
from {{ source('f1_raw', 'constructors') }}
qualify row_number() over (
    partition by constructorid::int
    order by trim(name), trim(constructorref), trim(nationality)
) = 1
