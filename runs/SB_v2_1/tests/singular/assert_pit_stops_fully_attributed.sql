-- Every pit stop (<= 60 s) must map to exactly one constructor-season row; a driver with results for
-- two constructors in one race would silently fan out or drop stops.
with stops as (
    select count(*) as n from {{ ref('stg_f1__pit_stops') }} where duration_ms <= 60000
),
modelled as (
    select sum(pit_stop_count) as n from {{ ref('mart_constructor_season_pit_stops') }}
)
select stops.n as expected, modelled.n as actual
from stops cross join modelled
where stops.n <> modelled.n
