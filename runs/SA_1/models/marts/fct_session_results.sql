-- Grand Prix and sprint results in one table. Source result ids are only unique within
-- their own source table (sprint ids overlap Grand Prix ids), so the key is
-- (session_type, source_result_id); `session_result_id` is a surrogate of that pair.
with unioned as (
    select 'race' as session_type, * from {{ ref('stg_results') }}
    union all
    select 'sprint' as session_type, * from {{ ref('stg_sprint_results') }}
)

select
    unioned.session_type || '-' || unioned.result_id as session_result_id,
    unioned.session_type,
    unioned.result_id as source_result_id,
    unioned.race_id,
    races.season,
    races.round,
    races.race_date,
    unioned.driver_id,
    unioned.constructor_id,
    constructors.constructor_name,
    unioned.grid,
    unioned.finish_position,
    unioned.position_order,
    unioned.points,
    unioned.laps,
    status.status,
    coalesce(unioned.finish_position = 1, false) as is_win,
    coalesce(unioned.finish_position between 1 and 3, false) as is_podium,
    unioned.fastest_lap_time_ms
from unioned
inner join {{ ref('stg_races') }} as races using (race_id)
left join {{ ref('stg_constructors') }} as constructors using (constructor_id)
left join {{ ref('stg_status') }} as status using (status_id)
