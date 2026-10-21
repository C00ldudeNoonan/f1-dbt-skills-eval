{#
    The raw feed can carry an exact copy of a constructor row. The 2026-10-21 feed did, for
    Ferrari (one copy's name had a trailing space). Trimming makes such copies identical, so
    distinct removes them. Conflicting copies (same id, different values) are not removed here.
    tests/assert_no_conflicting_duplicate_copies.sql fails the build for those.
#}
select distinct
    {{ clean_null('constructorid') }}::integer as constructor_id,
    {{ clean_null('constructorref') }} as constructor_ref,
    {{ clean_null('name') }} as constructor_name,
    {{ clean_null('nationality') }} as nationality

from {{ source('f1_raw', 'constructors') }}
