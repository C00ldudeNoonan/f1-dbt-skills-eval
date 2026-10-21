-- Every pit stop of at most 60s must land in exactly one constructor-season bucket.
select staged.n as staged_stops, mart.n as mart_stops
from (select count(*) as n from {{ ref('stg_ergast__pit_stops') }} where duration_ms <= 60000) as staged
cross join (select sum(pit_stop_count) as n from {{ ref('mart_constructor_season_pit_stops') }}) as mart
where staged.n <> mart.n
