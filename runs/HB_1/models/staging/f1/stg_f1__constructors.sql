with source as (

    select * from {{ source('f1_raw', 'constructors') }}

)

-- Exact duplicate rows are removed here. A warning test reports them (see tests/). Rows that share a
-- constructor_id but differ in content are kept, so the unique test on this model fails and stops the build.
select distinct
    cast(constructorid as int) as constructor_id,
    {{ na_to_null('constructorref') }} as constructor_ref,
    {{ na_to_null('name') }} as constructor_name,
    {{ na_to_null('nationality') }} as nationality
from source
