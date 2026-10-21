{#
    Every complete season must produce the official world champion from the
    reference seed. Only complete seasons are checked (is_season_complete), so an
    unfinished season never fails this test.
#}
with built as (

    select
        standings.season,
        drivers.driver_ref

    from {{ ref('mart_driver_season_standings') }} as standings
    inner join {{ ref('dim_drivers') }} as drivers
        on standings.driver_id = drivers.driver_id
    where standings.is_champion
        and standings.is_season_complete

)

select
    coalesce(built.season, official.season) as season,
    built.driver_ref as built_champion,
    official.driver_ref as official_champion

from built
full outer join {{ ref('official_world_champions') }} as official
    on built.season = official.season
where built.driver_ref is distinct from official.driver_ref
