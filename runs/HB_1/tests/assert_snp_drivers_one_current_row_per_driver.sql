select
    driverid,
    count(*) as current_rows
from {{ ref('snp_drivers') }}
where dbt_valid_to is null
group by driverid
having count(*) > 1
