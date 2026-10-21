{#
    One row per constructor per season that has pit stop data (2011 onwards).
    Stops longer than 60 seconds are excluded from both the count and the median: they are
    red-flag stoppages and do not reflect the pit crew's performance.
#}
with pit_stops as (

    select * from {{ ref('stg_f1__pit_stops') }}
    where stop_duration_ms <= 60000

),

race_entries as (

    select distinct
        race_id,
        season,
        driver_id,
        constructor_id
    from {{ ref('fct_results') }}

)

select
    race_entries.season,
    race_entries.constructor_id,
    count(*) as pit_stop_count,
    round(median(pit_stops.stop_duration_ms) / 1000.0, 3) as median_pit_stop_seconds
from pit_stops
inner join race_entries
    on pit_stops.race_id = race_entries.race_id
    and pit_stops.driver_id = race_entries.driver_id
group by
    race_entries.season,
    race_entries.constructor_id
