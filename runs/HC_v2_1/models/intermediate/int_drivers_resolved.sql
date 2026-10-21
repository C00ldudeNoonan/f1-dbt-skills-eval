{#
    One row per driver, with the career figures every version of dim_drivers exposes. Real drivers come from
    stg_f1__drivers. A driver ID that appears in results or qualifying before its driver record arrives gets a
    placeholder row (is_placeholder = true). The placeholder is replaced on the first run after the real record
    appears, because this model is rebuilt on every run.

    current_number is the permanent car number, null for drivers without one.
    career_starts counts distinct Grands Prix entered. career_wins and career_podiums are Grand Prix only.
    career_sprint_wins counts sprint wins. A world championship counts only for complete seasons, so an
    unfinished season never adds one.
#}
with real_drivers as (

    select
        driver_id,
        driver_ref,
        driver_number,
        forename,
        surname,
        nationality,
        date_of_birth,
        false as is_placeholder
    from {{ ref('stg_f1__drivers') }}

),

placeholder_drivers as (

    select
        driver_id,
        'unknown_driver_' || driver_id as driver_ref,
        cast(null as integer) as driver_number,
        'Unknown' as forename,
        'Driver ' || driver_id as surname,
        cast(null as varchar) as nationality,
        cast(null as date) as date_of_birth,
        true as is_placeholder
    from {{ ref('int_orphan_drivers') }}

),

drivers as (

    select * from real_drivers
    union all
    select * from placeholder_drivers

),

career_results as (

    select
        driver_id,
        count(distinct race_id) as career_starts,
        count_if(is_win) as career_wins,
        count_if(is_podium) as career_podiums
    from {{ ref('fct_results') }}
    group by driver_id

),

sprint_results as (

    select
        driver_id,
        count_if(is_win) as career_sprint_wins
    from {{ ref('fct_session_results') }}
    where session_type = 'sprint'
    group by driver_id

),

championships as (

    select
        driver_id,
        count_if(championship_position = 1 and is_season_complete) as world_championships
    from {{ ref('mart_driver_season_standings') }}
    group by driver_id

)

select
    drivers.driver_id,
    drivers.driver_ref,
    drivers.driver_number as current_number,
    drivers.forename,
    drivers.surname,
    drivers.nationality,
    drivers.date_of_birth,
    coalesce(career_results.career_starts, 0) as career_starts,
    coalesce(career_results.career_wins, 0) as career_wins,
    coalesce(career_results.career_podiums, 0) as career_podiums,
    coalesce(sprint_results.career_sprint_wins, 0) as career_sprint_wins,
    coalesce(championships.world_championships, 0) as world_championships,
    drivers.is_placeholder
from drivers
left join career_results
    on drivers.driver_id = career_results.driver_id
left join sprint_results
    on drivers.driver_id = sprint_results.driver_id
left join championships
    on drivers.driver_id = championships.driver_id
