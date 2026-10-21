-- mart_pit_stop_trends must count every service stop (<= 60 s) exactly once.
select expected.stops as expected_stops, actual.stops as mart_stops
from (select count(*) as stops from {{ ref('stg_ergast__pit_stops') }} where duration_ms <= {{ var('max_pit_stop_ms') }}) as expected
cross join (select sum(service_stops) as stops from {{ ref('mart_pit_stop_trends') }}) as actual
where expected.stops <> actual.stops
