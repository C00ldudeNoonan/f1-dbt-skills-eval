-- Official world championship totals for complete seasons (2024 is not complete in the source data).
select
    driver_ref,
    world_championships,
    expected_titles
from (
    select
        driver_ref,
        world_championships,
        case driver_ref
            when 'hamilton' then 7
            when 'michael_schumacher' then 7
            when 'fangio' then 5
            when 'vettel' then 4
        end as expected_titles
    from {{ ref('dim_drivers') }}
    where driver_ref in ('hamilton', 'michael_schumacher', 'fangio', 'vettel')
)
where world_championships <> expected_titles
