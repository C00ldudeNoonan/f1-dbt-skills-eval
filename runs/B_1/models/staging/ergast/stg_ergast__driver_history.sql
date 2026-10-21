{#
    Typed, renamed view of snp_drivers: one row per driver per version of their
    attributes. valid_to is null for the current version.
#}

with snapshot as (
    select * from {{ ref('snp_drivers') }}
)

select
    dbt_scd_id                          as driver_version_id,
    {{ ergast_int('driverid') }}        as driver_id,
    {{ ergast_clean('driverref') }}     as driver_ref,
    {{ ergast_int('number') }}          as permanent_number,
    {{ ergast_clean('code') }}          as driver_code,
    {{ ergast_clean('forename') }}      as forename,
    {{ ergast_clean('surname') }}       as surname,
    {{ ergast_clean('nationality') }}   as nationality_raw,
    dbt_valid_from                      as valid_from,
    dbt_valid_to                        as valid_to,
    dbt_valid_to is null                as is_current
from snapshot
