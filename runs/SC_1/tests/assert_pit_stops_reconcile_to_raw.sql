-- Every real (<= 60s) raw pit stop must land in the constructor-season mart exactly once.
select 1
from (
    select
        (select count(*) from {{ ref('stg_f1__pit_stops') }} where duration_ms <= 60000) as expected_stops,
        (select sum(pit_stop_count) from {{ ref('mart_constructor_season_pit_stops') }}) as mart_stops
)
where expected_stops <> mart_stops
