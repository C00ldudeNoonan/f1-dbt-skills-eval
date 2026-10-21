select
    statusid::int as status_id,
    trim(status) as status
from {{ source('f1_raw', 'status') }}
-- Exact duplicate rows in the raw dimension would fan out every join to it, so keep one row per key.
-- Rows that share a key but differ are caught by the source_no_conflicting_duplicates test.
qualify row_number() over (partition by status_id order by status) = 1
