-- For every driver in a race with pit stop data, stints must tile their laps
-- exactly: stint 1 starts on lap 1, each stint starts on the lap after the
-- previous one ended, and the stint laps add up to the laps recorded.

with stints as (
    select
        *,
        lag(end_lap) over (partition by race_id, driver_id order by stint_number) as previous_end_lap
    from {{ ref('fct_stints') }}
),

stint_totals as (
    select
        race_id,
        driver_id,
        sum(stint_laps) as stint_laps,
        count_if(
            (stint_number = 1 and start_lap <> 1)
            or (stint_number > 1 and start_lap <> previous_end_lap + 1)
        ) as broken_links
    from stints
    group by race_id, driver_id
),

lap_totals as (
    select
        lap_times.race_id,
        lap_times.driver_id,
        count(*) as laps
    from {{ ref('fct_lap_times') }} as lap_times
    where lap_times.race_id in (select race_id from {{ ref('stg_f1__pit_stops') }})
    group by lap_times.race_id, lap_times.driver_id
)

select
    coalesce(lap_totals.race_id, stint_totals.race_id) as race_id,
    coalesce(lap_totals.driver_id, stint_totals.driver_id) as driver_id,
    lap_totals.laps,
    stint_totals.stint_laps,
    stint_totals.broken_links
from lap_totals
full outer join stint_totals
    on lap_totals.race_id = stint_totals.race_id
    and lap_totals.driver_id = stint_totals.driver_id
where lap_totals.laps is distinct from stint_totals.stint_laps
    or stint_totals.broken_links > 0
