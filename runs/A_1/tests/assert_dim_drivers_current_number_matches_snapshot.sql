-- dim_drivers.current_number must equal the number on each driver's open
-- (current) snapshot version, i.e. the snapshot and the dimension agree on
-- what "current" is.

with current_versions as (
    select
        {{ to_int('driverid') }} as driver_id,
        {{ to_int('number') }}   as snapshot_number
    from {{ ref('snp_drivers') }}
    where dbt_valid_to is null
)

select
    dim.driver_id,
    dim.current_number,
    snap.snapshot_number
from {{ ref('dim_drivers') }} as dim
left join current_versions as snap
    on dim.driver_id = snap.driver_id
where snap.driver_id is null
   or not equal_null(dim.current_number, snap.snapshot_number)
