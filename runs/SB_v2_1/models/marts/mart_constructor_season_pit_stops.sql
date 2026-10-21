-- Grain: one row per constructor per season with pit stop data.
-- Stops over 60 seconds (red-flag stoppages) are excluded from both the count and the median.

with pit_stops as (
    select * from {{ ref('stg_f1__pit_stops') }}
    where duration_ms <= 60000
),

-- A driver's constructor in a race comes from results; a driver who drove for two constructors in
-- one race would fan out here, which is guarded by a test on this model's grain.
entries as (
    select distinct race_id, driver_id, constructor_id, season
    from {{ ref('fct_results') }}
)

select
    entries.season,
    entries.constructor_id,
    count(*)::integer as pit_stop_count,
    (median(pit_stops.duration_ms) / 1000)::number(10, 4) as median_pit_stop_seconds
from pit_stops
inner join entries
    on entries.race_id = pit_stops.race_id
    and entries.driver_id = pit_stops.driver_id
group by 1, 2
