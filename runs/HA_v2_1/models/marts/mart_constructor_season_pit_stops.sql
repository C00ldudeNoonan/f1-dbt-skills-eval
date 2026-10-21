{#
    Grain: one row per constructor per season that has at least one pit stop
    after the red-flag exclusion. Constructor comes from the result for that driver
    and race. Stops longer than max_pit_stop_duration_ms are excluded.
    median_pit_stop_seconds is the median stop duration in seconds.
#}
with pit_stops as (

    select
        pit_stops.race_id,
        pit_stops.driver_id,
        pit_stops.duration_ms
    from {{ ref('stg_f1__pit_stops') }} as pit_stops
    where pit_stops.duration_ms <= {{ var('max_pit_stop_duration_ms') }}

),

race_constructors as (

    select distinct
        race_id,
        driver_id,
        constructor_id,
        season
    from {{ ref('fct_results') }}

)

select
    race_constructors.season,
    race_constructors.constructor_id,
    count(*) as pit_stop_count,
    median(pit_stops.duration_ms) / 1000.0 as median_pit_stop_seconds
from pit_stops
inner join race_constructors
    on pit_stops.race_id = race_constructors.race_id
    and pit_stops.driver_id = race_constructors.driver_id
group by
    race_constructors.season,
    race_constructors.constructor_id
