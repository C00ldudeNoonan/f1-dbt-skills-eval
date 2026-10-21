{#
  One row per entry in any points-scoring session: Grands Prix ('race') and
  sprints ('sprint', 2021+). Every entry is included, classified or not.

  Source result ids are only unique within their own table (Grand Prix and
  sprint ids overlap), so the grain is (session_type, source_result_id);
  session_result_id is a surrogate key over that pair.

  fct_results remains the Grand Prix-only fact (with fastest-lap detail);
  assert_session_results_reconcile_to_fct_results keeps the two in step.
#}

with race_results as (
    select
        'race'              as session_type,
        result_id           as source_result_id,
        race_id,
        driver_id,
        constructor_id,
        grid,
        finish_position,
        position_text,
        position_order,
        points,
        laps,
        status_id
    from {{ ref('stg_ergast__results') }}
),

sprint_results as (
    select
        'sprint'            as session_type,
        sprint_result_id    as source_result_id,
        race_id,
        driver_id,
        constructor_id,
        grid,
        finish_position,
        position_text,
        position_order,
        points,
        laps,
        status_id
    from {{ ref('stg_ergast__sprint_results') }}
),

session_results as (
    select * from race_results
    union all
    select * from sprint_results
),

races as (
    select * from {{ ref('stg_ergast__races') }}
),

constructors as (
    select * from {{ ref('stg_ergast__constructors') }}
),

status as (
    select * from {{ ref('stg_ergast__status') }}
)

select
    session_results.session_type || '-' || session_results.source_result_id as session_result_id,
    session_results.session_type,
    session_results.source_result_id,
    session_results.race_id,
    races.season,
    races.round,
    races.race_name,
    case session_results.session_type
        when 'sprint' then coalesce(races.sprint_date, races.race_date)
        else races.race_date
    end                                                     as session_date,
    session_results.driver_id,
    session_results.constructor_id,
    constructors.constructor_name,
    session_results.grid,
    session_results.finish_position,
    session_results.position_text,
    session_results.position_order,
    session_results.points,
    session_results.laps,
    status.status,
    session_results.finish_position is not null             as is_classified,
    coalesce(session_results.finish_position = 1, false)    as is_win,
    coalesce(session_results.finish_position <= 3, false)   as is_podium
from session_results
inner join races
    on session_results.race_id = races.race_id
left join constructors
    on session_results.constructor_id = constructors.constructor_id
left join status
    on session_results.status_id = status.status_id
