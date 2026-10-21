{{ config(severity='warn') }}
-- The raw CONSTRUCTORS table should have one row per constructorid. Duplicates are cleaned up in
-- staging (identical rows collapse, conflicting ones fail the unique test), but the vendor should
-- hear about them. Returns each duplicated id with its row count.
select
    constructorid,
    count(*) as raw_rows
from {{ source('ergast', 'constructors') }}
group by constructorid
having count(*) > 1
