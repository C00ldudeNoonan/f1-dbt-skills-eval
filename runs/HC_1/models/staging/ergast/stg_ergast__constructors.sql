-- `distinct` collapses rows that are identical once cleaned. The vendor sent Ferrari twice in one
-- load, with the name differing only by a trailing space. If two rows still conflict after cleaning,
-- the unique test on constructor_id fails and stops the build before it reaches the marts.
with source as (

    select * from {{ source('ergast', 'constructors') }}

)

select distinct
    try_to_number(constructorid) as constructor_id,
    trim(constructorref) as constructor_ref,
    trim(name) as constructor_name,
    trim(nationality) as nationality

from source
