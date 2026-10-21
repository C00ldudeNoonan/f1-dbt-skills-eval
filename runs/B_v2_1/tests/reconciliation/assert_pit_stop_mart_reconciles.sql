-- mart_constructor_season_pit_stops must count each eligible pit stop exactly once:
-- every stop of 60 s or less whose driver has a Grand Prix result in that race.
-- A fan-out (e.g. a duplicated team or result row) makes the mart's total larger.
with expected as (
    select count(*) as stops
    from {{ ref('stg_ergast__pit_stops') }} as stops
    where stops.duration_ms <= {{ var('max_pit_stop_ms') }}
        and exists (
            select 1 from {{ ref('stg_ergast__results') }} as results
            where results.race_id = stops.race_id and results.driver_id = stops.driver_id
        )
),

actual as (
    select sum(pit_stop_count) as stops from {{ ref('mart_constructor_season_pit_stops') }}
)

select expected.stops as expected_stops, actual.stops as mart_stops
from expected cross join actual
where expected.stops <> actual.stops
