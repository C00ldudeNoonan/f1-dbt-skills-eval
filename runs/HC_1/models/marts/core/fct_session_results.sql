-- One row per classification entry across every session: Grands Prix and sprints.
-- `source_result_id` is the id in the source table. Result ids are only unique within a session type,
-- so `session_result_id` combines the two.
with race_entries as (

    select
        'race' as session_type,
        result_id as source_result_id,
        race_id,
        season,
        round,
        driver_id,
        constructor_id,
        finish_position,
        points
    from {{ ref('fct_results') }}

),

sprint_entries as (

    select
        'sprint' as session_type,
        sprint_results.sprint_result_id as source_result_id,
        sprint_results.race_id,
        races.season,
        races.round,
        sprint_results.driver_id,
        sprint_results.constructor_id,
        sprint_results.finish_position,
        sprint_results.points
    from {{ ref('stg_ergast__sprint_results') }} as sprint_results
    inner join {{ ref('stg_ergast__races') }} as races
        on sprint_results.race_id = races.race_id

)

select
    concat(session_type, '-', source_result_id) as session_result_id,
    *
from (
    select * from race_entries
    union all
    select * from sprint_entries
)
