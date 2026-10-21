select
    results.result_id,
    results.race_id,
    races.season,
    races.round,
    races.race_date,
    results.driver_id,
    results.constructor_id,
    constructors.constructor_name,
    results.grid,
    results.finish_position,
    results.position_order,
    results.points,
    results.laps,
    status.status,
    coalesce(results.finish_position = 1, false) as is_win,
    coalesce(results.finish_position between 1 and 3, false) as is_podium,
    results.fastest_lap_time_ms
from {{ ref('stg_results') }} as results
inner join {{ ref('stg_races') }} as races using (race_id)
left join {{ ref('stg_constructors') }} as constructors using (constructor_id)
left join {{ ref('stg_status') }} as status using (status_id)
