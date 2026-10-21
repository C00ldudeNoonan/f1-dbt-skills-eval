{#
    Within each points system and season, every driver has one row and every alt_position
    from 1 to the number of drivers appears exactly once.
#}
with per_season as (

    select
        points_system,
        season,
        count(*) as drivers,
        count(distinct driver_id) as distinct_drivers,
        count(distinct alt_position) as distinct_positions,
        max(alt_position) as max_position
    from {{ ref('mart_alt_points_standings') }}
    group by points_system, season

)

select *
from per_season
where drivers <> distinct_drivers
    or distinct_positions <> drivers
    or max_position <> drivers
