select
    constructorid::int as constructor_id,
    trim(constructorref) as constructor_ref,
    trim(name) as constructor_name,
    trim({{ clean_null('nationality') }}) as nationality
from {{ source('f1_raw', 'constructors') }}
-- Exact duplicate rows in the raw dimension would fan out every join to it, so keep one row per key.
-- Rows that share a key but differ are caught by the source_no_conflicting_duplicates test.
qualify row_number() over (partition by constructor_id order by constructor_ref, constructor_name, nationality) = 1
