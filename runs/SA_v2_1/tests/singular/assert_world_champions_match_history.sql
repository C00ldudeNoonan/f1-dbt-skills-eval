-- Spot-check the standings against well-known champions (driver_ref, season).
with known as (
    select * from (values
        ('farina', 1950), ('fangio', 1951), ('ascari', 1953), ('hawthorn', 1958),
        ('stewart', 1971), ('lauda', 1977), ('prost', 1993), ('michael_schumacher', 2004),
        ('hamilton', 2008), ('vettel', 2013), ('rosberg', 2016), ('max_verstappen', 2023)
    ) as t(driver_ref, season)
)

select known.driver_ref, known.season
from known
left join {{ ref('dim_drivers') }} as drivers on known.driver_ref = drivers.driver_ref
left join {{ ref('mart_driver_season_standings') }} as standings
    on drivers.driver_id = standings.driver_id
    and known.season = standings.season
    and standings.championship_position = 1
where standings.driver_id is null
