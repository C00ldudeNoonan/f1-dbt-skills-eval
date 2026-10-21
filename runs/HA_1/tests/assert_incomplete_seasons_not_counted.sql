-- Championships only count for complete seasons: the total in dim_drivers must equal
-- the complete-season champion rows in the standings mart.
with dim_total as (

    select sum(world_championships) as championships
    from {{ ref('dim_drivers') }}

),

mart_total as (

    select count(*) as championships
    from {{ ref('mart_driver_season_standings') }}
    where is_season_complete
        and championship_position = 1

)

select *
from dim_total
cross join mart_total
where dim_total.championships <> mart_total.championships
