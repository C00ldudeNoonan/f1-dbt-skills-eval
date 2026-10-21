-- Spot checks against published final standings: points include sprint points from 2021,
-- and the 2014 and 2023 totals are the official ones.
with expected as (
    select * from (values
        (1950, 'farina', 30.00, 1),
        (2014, 'hamilton', 384.00, 1),
        (2014, 'rosberg', 317.00, 2),
        (2021, 'max_verstappen', 395.50, 1),
        (2021, 'hamilton', 387.50, 2),
        (2023, 'max_verstappen', 575.00, 1)
    ) as t (season, driver_ref, expected_points, expected_position)
),

actual as (
    select
        standings.season,
        drivers.driver_ref,
        standings.points,
        standings.championship_position
    from {{ ref('mart_driver_season_standings') }} as standings
    inner join {{ ref('dim_drivers') }} as drivers
        on drivers.driver_id = standings.driver_id
)

select
    expected.season,
    expected.driver_ref,
    expected.expected_points,
    actual.points,
    expected.expected_position,
    actual.championship_position
from expected
left join actual
    on actual.season = expected.season
    and actual.driver_ref = expected.driver_ref
where actual.points is null
    or actual.points <> expected.expected_points
    or actual.championship_position <> expected.expected_position
