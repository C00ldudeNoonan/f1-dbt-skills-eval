-- Every genuine (<= 60s) pit stop in staging must be counted exactly once in
-- the mart, i.e. the constructor lookup neither drops nor fans out stops.
with staged as (
    select count(*) as n
    from {{ ref('stg_ergast__pit_stops') }}
    where duration_seconds <= {{ var('max_pit_stop_seconds') }}
),

mart as (
    select sum(pit_stop_count) as n
    from {{ ref('mart_constructor_season_pit_stops') }}
)

select staged.n as staged_stops, mart.n as mart_stops
from staged cross join mart
where staged.n != mart.n
