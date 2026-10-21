-- Every pit stop under the red-flag threshold must land in the constructor mart.
with staged as (

    select count(*) as stops
    from {{ ref('stg_ergast__pit_stops') }}
    where duration_ms <= {{ var('pit_stop_max_seconds') }} * 1000

),

mart as (

    select sum(pit_stop_count) as stops
    from {{ ref('mart_constructor_season_pit_stops') }}

)

select staged.stops as staged_stops, mart.stops as mart_stops
from staged
cross join mart
where staged.stops != mart.stops
