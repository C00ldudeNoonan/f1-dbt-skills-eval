-- dim_drivers.world_championships must equal the number of titles in the
-- reference list for every driver.
with official as (

    select driver_ref, count(*) as titles
    from {{ ref('known_world_champions') }}
    group by driver_ref

)

select
    drivers.driver_ref,
    drivers.world_championships,
    coalesce(official.titles, 0) as official_titles
from {{ ref('dim_drivers') }} as drivers
left join official
    on drivers.driver_ref = official.driver_ref
where drivers.world_championships != coalesce(official.titles, 0)
