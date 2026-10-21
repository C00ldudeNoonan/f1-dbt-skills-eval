-- The Grand Prix rows of fct_session_results must match fct_results exactly
-- (same entries, drivers, positions and points), and the sprint rows must
-- cover every sprint source row. Guards against the two facts drifting.

with gp_sessions as (
    select source_result_id as result_id, race_id, driver_id, constructor_id, finish_position, points
    from {{ ref('fct_session_results') }}
    where session_type = 'race'
),

gp_results as (
    select result_id, race_id, driver_id, constructor_id, finish_position, points
    from {{ ref('fct_results') }}
),

gp_diff as (
    (select 'only_in_session_results' as issue, * from gp_sessions
     minus
     select 'only_in_session_results', * from gp_results)
    union all
    (select 'only_in_fct_results', * from gp_results
     minus
     select 'only_in_fct_results', * from gp_sessions)
),

sprint_diff as (
    select 'sprint_count_mismatch' as issue, null, null, null, null, null, null
    where (select count(*) from {{ ref('fct_session_results') }} where session_type = 'sprint')
       <> (select count(*) from {{ ref('stg_ergast__sprint_results') }})
)

select * from gp_diff
union all
select * from sprint_diff
