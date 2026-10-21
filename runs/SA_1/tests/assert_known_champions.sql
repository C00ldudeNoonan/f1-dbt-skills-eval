-- Spot-check against real history.
with expected as (
    select * from (values
        (1950, 'Farina', 30.0), (1958, 'Hawthorn', 42.0), (1976, 'Hunt', 69.0),
        (1984, 'Lauda', 72.0), (2008, 'Hamilton', 98.0), (2021, 'Verstappen', 395.5)
    ) as t(season, surname, points)
)
select expected.season
from expected
left join {{ ref('mart_driver_season_standings') }} as standings
    on standings.season = expected.season and standings.championship_position = 1
left join {{ ref('stg_drivers') }} as drivers using (driver_id)
where drivers.surname is distinct from expected.surname
   or standings.points is distinct from expected.points
