-- For races with pit data, stints must partition each driver's laps exactly.
select stints.race_id, stints.driver_id
from {{ ref('fct_stints') }} as stints
inner join (
    select race_id, driver_id, count(*) as laps, max(lap) as last_lap
    from {{ ref('fct_lap_times') }}
    group by race_id, driver_id
) as laps using (race_id, driver_id)
group by stints.race_id, stints.driver_id, laps.laps, laps.last_lap
having sum(stints.stint_laps) <> max(laps.laps)
    or max(stints.end_lap) <> max(laps.last_lap)
    or min(stints.start_lap) <> 1
