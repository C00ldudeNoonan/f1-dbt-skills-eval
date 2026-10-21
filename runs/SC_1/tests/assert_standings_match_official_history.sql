-- Spot checks against published history, chosen where summing race points or a naive
-- "max round as text" would give the wrong answer (dropped results, text sorting, DSQ).
with expected as (

    select * from (values
        (1958, 'hawthorn',           42.0),
        (1964, 'surtees',            40.0),
        (1976, 'hunt',               69.0),
        (1984, 'lauda',              72.0),
        (1988, 'senna',              90.0),
        (1997, 'villeneuve',         81.0),
        (2008, 'hamilton',           98.0),
        (2021, 'max_verstappen',    395.5)
    ) as t (season, champion_driver_ref, champion_points)

),

actual as (

    select standings.season, drivers.driver_ref, standings.points
    from {{ ref('mart_driver_season_standings') }} as standings
    inner join {{ ref('dim_drivers') }} as drivers using (driver_id)
    where standings.championship_position = 1

)

select expected.*, actual.driver_ref, actual.points
from expected
left join actual on expected.season = actual.season
where actual.driver_ref is distinct from expected.champion_driver_ref
    or actual.points <> expected.champion_points
