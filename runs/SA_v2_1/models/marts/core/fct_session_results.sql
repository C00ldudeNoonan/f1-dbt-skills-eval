-- One row per entry across Grand Prix and sprint sessions. The two source tables have
-- overlapping result ids, so the key is (session_type, source_result_id).
select
    'race' as session_type,
    result_id as source_result_id,
    race_id,
    season,
    round,
    driver_id,
    constructor_id,
    finish_position,
    position_order,
    points,
    is_win,
    is_podium
from {{ ref('fct_results') }}

union all

select
    'sprint' as session_type,
    sprint.result_id as source_result_id,
    sprint.race_id,
    races.season,
    races.round,
    sprint.driver_id,
    sprint.constructor_id,
    sprint.finish_position,
    sprint.position_order,
    sprint.points,
    coalesce(sprint.finish_position = 1, false) as is_win,
    coalesce(sprint.finish_position <= 3, false) as is_podium
from {{ ref('stg_ergast__sprint_results') }} as sprint
inner join {{ ref('stg_ergast__races') }} as races on sprint.race_id = races.race_id
