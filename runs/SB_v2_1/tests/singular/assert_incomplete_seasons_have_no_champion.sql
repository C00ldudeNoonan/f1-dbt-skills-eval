-- Total championships credited must equal the number of complete seasons with a position-1 driver.
with credited as (
    select sum(world_championships) as n from {{ ref('dim_drivers') }}
),
expected as (
    select count(*) as n
    from {{ ref('mart_driver_season_standings') }} as standings
    inner join {{ ref('int_season_status') }} as status using (season)
    where standings.championship_position = 1 and status.is_complete
)
select credited.n as credited, expected.n as expected
from credited cross join expected
where credited.n <> expected.n
