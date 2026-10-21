select
    driver_id,
    count(*) as current_rows

from {{ ref('snp_drivers') }}
where dbt_valid_to is null
group by driver_id
having count(*) <> 1
