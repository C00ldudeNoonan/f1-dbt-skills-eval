-- Warns when the vendor sends the same constructor twice. Staging removes exact duplicates,
-- so the build continues. Remove this test once the vendor fixes the feed.
{{ config(severity='warn') }}

select
    constructorid,
    count(*) as copies
from {{ source('f1_raw', 'constructors') }}
group by constructorid
having count(*) > 1
