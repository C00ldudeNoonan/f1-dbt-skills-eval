{#
    Every complete season with a champion is counted exactly once in dim_drivers.
    Returns a row if the total differs from the number of champion seasons in the
    reference seed (1950 to 2024), which would mean an incomplete season leaked in.
#}
with titles_counted as (

    select sum(world_championships) as titles
    from {{ ref('dim_drivers') }}

),

titles_expected as (

    select count(*) as titles
    from {{ ref('known_world_champions') }}

)

select *
from titles_counted
cross join titles_expected
where titles_counted.titles <> titles_expected.titles
