{#
    The standings mart must name the same champion as published history for every
    season in the reference seed. Returns the seasons that disagree.
#}
select
    champions.season,
    champions.driver_ref as expected_driver_ref,
    drivers.driver_ref as actual_driver_ref
from {{ ref('known_world_champions') }} as champions
left join {{ ref('mart_driver_season_standings') }} as standings
    on champions.season = standings.season
    and standings.championship_position = 1
    and standings.is_season_complete
left join {{ ref('stg_f1__drivers') }} as drivers
    on standings.driver_id = drivers.driver_id
where drivers.driver_ref is null
    or drivers.driver_ref <> champions.driver_ref
