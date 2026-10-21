-- Every driver in the source has exactly one open (current) snapshot version.
select drivers.driver_id, count(history.driver_id) as current_versions
from {{ ref('stg_ergast__drivers') }} as drivers
left join {{ ref('stg_ergast__driver_history') }} as history
    on drivers.driver_id = history.driver_id
    and history.is_current
group by drivers.driver_id
having count(history.driver_id) != 1
