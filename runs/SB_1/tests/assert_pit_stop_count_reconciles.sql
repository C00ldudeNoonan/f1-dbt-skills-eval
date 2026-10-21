-- Every in-scope pit stop (<= 60s, with a matching result) lands in exactly one constructor-season.
with expected as (
    select count(*) as n
    from {{ ref('stg_f1__pit_stops') }} as stops
    where duration_ms <= 60000
      and exists (
        select 1 from {{ ref('stg_f1__results') }} as r
        where r.race_id = stops.race_id and r.driver_id = stops.driver_id
      )
),
actual as (
    select sum(pit_stop_count) as n from {{ ref('mart_constructor_season_pit_stops') }}
)
select expected.n as expected_stops, actual.n as mart_stops
from expected, actual
where expected.n <> actual.n
