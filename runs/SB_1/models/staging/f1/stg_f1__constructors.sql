-- The vendor feed has shipped a duplicate constructor row (Ferrari, id 6; the copy has a trailing
-- space in `name`, so it is not byte-identical), which
-- fans out every join to constructors and doubles that team's results. Keep one row per id.
-- Duplicates are flagged by the warn-level unique test on the source (_f1__sources.yml);
-- conflicting (after trimming) duplicates would fail `assert_no_conflicting_constructor_duplicates`.
select
    constructorid::int                              as constructor_id,
    trim(constructorref)                            as constructor_ref,
    trim(name)                                      as constructor_name,
    {{ clean_null('nationality') }}                 as nationality
from {{ source('f1_raw', 'constructors') }}
qualify row_number() over (
    partition by constructorid
    order by trim(constructorref), trim(name), nationality
) = 1
