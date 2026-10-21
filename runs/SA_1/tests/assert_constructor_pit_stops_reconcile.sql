-- Every real (<= 60s) pit stop is attributed to exactly one constructor-season.
select mart.stops, expected.stops as expected_stops
from (select sum(pit_stop_count) as stops from {{ ref('mart_constructor_season_pit_stops') }}) as mart,
     (
        select count(*) as stops
        from {{ ref('stg_pit_stops') }} as p
        inner join {{ ref('stg_results') }} as r using (race_id, driver_id)
        where p.duration_ms <= 60000
     ) as expected
where mart.stops <> expected.stops
