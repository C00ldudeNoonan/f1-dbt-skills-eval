{#
    Pit stop summary per constructor per season.
    Stops longer than the red-flag threshold (60 seconds) are excluded from
    both the count and the median. Pit stop data starts in 2011.
    The constructor is the one the driver raced for in that Grand Prix.
#}
with pit_stops as (

    select * from {{ ref('stg_f1__pit_stops') }}

),

results as (

    select
        race_id,
        driver_id,
        season,
        constructor_id

    from {{ ref('fct_results') }}

),

valid_stops as (

    select
        results.season,
        results.constructor_id,
        pit_stops.pit_stop_ms

    from pit_stops
    inner join results
        on pit_stops.race_id = results.race_id
        and pit_stops.driver_id = results.driver_id
    where pit_stops.pit_stop_ms <= {{ var('red_flag_pit_stop_ms') }}

)

select
    season,
    constructor_id,
    count(*) as pit_stop_count,
    round(median(pit_stop_ms) / 1000, 3) as median_pit_stop_seconds

from valid_stops
group by season, constructor_id
