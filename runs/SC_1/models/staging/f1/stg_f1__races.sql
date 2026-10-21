select
    raceid::int as race_id,
    year::int as season,
    round::int as round,
    circuitid::int as circuit_id,
    trim(name) as race_name,
    date::date as race_date
from {{ source('f1_raw', 'races') }}
-- Exact duplicate rows in the raw dimension would fan out every join to it, so keep one row per key.
-- Rows that share a key but differ are caught by the source_no_conflicting_duplicates test.
qualify row_number() over (partition by race_id order by season, round, race_name) = 1
