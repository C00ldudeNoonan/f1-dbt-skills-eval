-- Each driver has at most one current version in the snapshot, and the
-- validity windows of their versions don't overlap.
with versions as (
    select
        driver_id,
        dbt_valid_from,
        dbt_valid_to,
        lead(dbt_valid_from) over (partition by driver_id order by dbt_valid_from) as next_valid_from
    from {{ ref('snp_drivers') }}
)

select driver_id
from versions
group by driver_id
having count_if(dbt_valid_to is null) > 1
    or count_if(next_valid_from is not null and dbt_valid_to is distinct from next_valid_from) > 0
