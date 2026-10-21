-- Version 2: one row per driver with first_name and last_name (replaces full_name). Career totals come from fct_results (Grand Prix only).
-- Latest version. Replaces full_name with first_name and last_name; dim_drivers_v1 is deprecated on 2027-01-01.

with drivers as (

    select * from {{ ref('stg_f1__drivers') }}

),

career_totals as (

    select
        driver_id,
        count(distinct race_id) as career_starts,
        count(distinct case when is_win then race_id end) as career_wins,
        count(distinct case when is_podium then race_id end) as career_podiums
    from {{ ref('fct_results') }}
    group by driver_id

),

sprint_totals as (

    select
        driver_id,
        count(distinct case when is_win then race_id end) as career_sprint_wins
    from {{ ref('fct_session_results') }}
    where session_type = 'sprint'
    group by driver_id

),

championships as (

    select * from {{ ref('int_f1__driver_championships') }}

)

select
    drivers.driver_id,
    drivers.driver_ref,
    drivers.first_name,
    drivers.last_name,
    drivers.nationality,
    drivers.date_of_birth,
    drivers.permanent_number as current_number,
    coalesce(career_totals.career_starts, 0) as career_starts,
    coalesce(career_totals.career_wins, 0) as career_wins,
    coalesce(career_totals.career_podiums, 0) as career_podiums,
    coalesce(sprint_totals.career_sprint_wins, 0) as career_sprint_wins,
    coalesce(championships.world_championships, 0) as world_championships
from drivers
left join career_totals
    on drivers.driver_id = career_totals.driver_id
left join sprint_totals
    on drivers.driver_id = sprint_totals.driver_id
left join championships
    on drivers.driver_id = championships.driver_id
