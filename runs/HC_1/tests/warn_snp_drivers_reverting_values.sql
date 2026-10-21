{{ config(severity='warn') }}
-- Flags a driver attribute that changes and then returns to an earlier value (A -> B -> A).
-- Real changes are rare and one-way, so a revert usually means a transient or bad source write.
-- Warn-only: investigate the source before trusting these versions. Returns offending rows.
with versions as (

    select
        driverid,
        number,
        code,
        forename,
        surname,
        dob,
        nationality,
        dbt_valid_from,
        lag(number) over (partition by driverid order by dbt_valid_from) as prev_number,
        lead(number) over (partition by driverid order by dbt_valid_from) as next_number
    from {{ ref('snp_drivers') }}

)

select
    driverid,
    dbt_valid_from,
    number,
    prev_number,
    next_number
from versions
where prev_number is not null
    and next_number = prev_number
    and number <> prev_number
