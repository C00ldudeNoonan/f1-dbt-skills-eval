-- Every driver has exactly one current (open) version in the snapshot. Returns offending drivers.
select
    driverid,
    count(*) as current_versions
from {{ ref('snp_drivers') }}
where dbt_valid_to is null
group by driverid
having count(*) <> 1
