-- v1 and v2 must describe the same drivers, and full_name must equal first_name || ' ' || last_name.
select v1.driver_id
from {{ ref('dim_drivers', v=1) }} as v1
full outer join {{ ref('dim_drivers', v=2) }} as v2 on v1.driver_id = v2.driver_id
where v1.driver_id is null
   or v2.driver_id is null
   or v1.full_name is distinct from v2.first_name || ' ' || v2.last_name
   or v1.is_placeholder <> v2.is_placeholder
   or v1.career_starts <> v2.career_starts
   or v1.world_championships <> v2.world_championships
