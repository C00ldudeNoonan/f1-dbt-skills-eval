{#- Type 2 driver history from snp_drivers: one row per driver per version. -#}
select
    dbt_scd_id                  as driver_version_id,
    driver_id,
    driver_ref,
    permanent_number,
    driver_code,
    forename,
    surname,
    full_name,
    nationality,
    date_of_birth,
    dbt_valid_from              as valid_from,
    dbt_valid_to                as valid_to,
    dbt_valid_to is null        as is_current
from {{ ref('snp_drivers') }}
