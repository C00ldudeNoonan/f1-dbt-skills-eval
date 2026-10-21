-- Every lap of a race with pit stop data falls in exactly one stint, and stint
-- averages agree with the current lap times.
with laps as (

    select race_id, driver_id, count(*) as laps, sum(lap_time_ms) as total_ms
    from {{ ref('fct_lap_times') }}
    where race_id in (select race_id from {{ ref('stg_ergast__pit_stops') }})
    group by 1, 2

),

stints as (

    select race_id, driver_id, sum(stint_laps) as laps,
        sum(avg_lap_time_ms * stint_laps) as total_ms
    from {{ ref('fct_stints') }}
    group by 1, 2

)

select laps.*, stints.laps as stint_laps, stints.total_ms as stint_total_ms
from laps
full outer join stints
    on laps.race_id = stints.race_id
    and laps.driver_id = stints.driver_id
where laps.laps is distinct from stints.laps
    or abs(laps.total_ms - stints.total_ms) > 1
    or laps.total_ms is null or stints.total_ms is null
