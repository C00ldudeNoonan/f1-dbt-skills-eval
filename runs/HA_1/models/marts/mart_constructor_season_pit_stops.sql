-- One row per constructor per season with pit stop data.
-- Stops longer than 60 seconds are red-flag stoppages, not pit stops, and are excluded.

with pit_stops as (

    select * from {{ ref('stg_f1__pit_stops') }}
    where pit_stop_duration_ms <= 60000

),

stops_with_constructor as (

    select
        fct_results.season,
        fct_results.constructor_id,
        pit_stops.pit_stop_duration_ms
    from pit_stops
    inner join {{ ref('fct_results') }} as fct_results
        on pit_stops.race_id = fct_results.race_id
        and pit_stops.driver_id = fct_results.driver_id

)

select
    season,
    constructor_id,
    count(*) as pit_stop_count,
    round(median(pit_stop_duration_ms) / 1000, 3) as median_pit_stop_seconds
from stops_with_constructor
group by season, constructor_id
