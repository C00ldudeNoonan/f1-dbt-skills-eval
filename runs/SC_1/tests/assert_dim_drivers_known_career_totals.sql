-- Anchor values from published records for retired drivers, so they don't move as new races land.
with expected as (

    select * from (values
        ('michael_schumacher', 308,  91, 155, 7),
        ('vettel',             300,  53, 122, 4),
        ('prost',              202,  51, 106, 4),
        ('fangio',              51,  24,  35, 5)
    ) as t (driver_ref, starts, wins, podiums, titles)

)

select expected.*, dim.career_starts, dim.career_wins, dim.career_podiums, dim.world_championships
from expected
left join {{ ref('dim_drivers') }} as dim using (driver_ref)
where dim.career_starts is distinct from expected.starts
    or dim.career_wins is distinct from expected.wins
    or dim.career_podiums is distinct from expected.podiums
    or dim.world_championships is distinct from expected.titles
