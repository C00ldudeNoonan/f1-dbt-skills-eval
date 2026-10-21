-- Each driver has exactly one current (open) version in the snapshot.
select driver_id, count(*) as current_versions
from {{ ref('snp_drivers') }}
where dbt_valid_to is null
group by driver_id
having count(*) != 1
