-- Every valid pit stop (60 seconds or less) must land in exactly one constructor-season row.
-- Returns a row only when the counts disagree.
with valid_stops as (

    select count(*) as stop_count
    from {{ ref('stg_ergast__pit_stops') }}
    where duration_ms <= 60000

),

attributed_stops as (

    select sum(pit_stop_count) as stop_count
    from {{ ref('mart_constructor_season_pit_stops') }}

)

select
    valid_stops.stop_count as valid_stop_count,
    attributed_stops.stop_count as attributed_stop_count
from valid_stops
cross join attributed_stops
where valid_stops.stop_count <> attributed_stops.stop_count
