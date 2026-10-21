{#
    The current version of every driver in snp_drivers (dbt_valid_to is null) must match the
    drivers staging model. A driver with no current version, or a stale one, fails here.
#}
with current_snapshot as (

    select * from {{ ref('snp_drivers') }}
    where dbt_valid_to is null

),

drivers as (

    select * from {{ ref('stg_f1__drivers') }}

)

select
    drivers.driver_id
from drivers
left join current_snapshot
    on drivers.driver_id = current_snapshot.driver_id
where current_snapshot.driver_id is null
    or current_snapshot.driver_number is distinct from drivers.driver_number
    or current_snapshot.driver_code is distinct from drivers.driver_code
    or current_snapshot.driver_ref is distinct from drivers.driver_ref
