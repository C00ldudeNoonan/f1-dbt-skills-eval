{#
    distinct, because the vendor can send an identical copy of a constructor row. The unique test on
    constructor_id in the staging YAML fails if the copies ever disagree, so conflicting duplicates stop the build.
#}
select distinct
    {{ null_if_sentinel('CONSTRUCTORID') }}::integer as constructor_id,
    {{ null_if_sentinel('CONSTRUCTORREF') }} as constructor_ref,
    {{ null_if_sentinel('NAME') }} as constructor_name,
    {{ null_if_sentinel('NATIONALITY') }} as nationality
from {{ source('f1_raw', 'CONSTRUCTORS') }}
