{#
    dim_drivers v2 (latest): one row per driver with career totals.
    Public interface (contract enforced). v2 replaces v1's full_name and
    forename / surname with first_name / last_name. v1 is a thin
    compatibility layer over this model (dim_drivers_v1.sql).
#}

with drivers as (
    select * from {{ ref('stg_ergast__drivers') }}
),

results as (
    select * from {{ ref('fct_results') }}
),

session_results as (
    select * from {{ ref('fct_session_results') }}
),

season_standings as (
    select * from {{ ref('mart_driver_season_standings') }}
),

career as (
    select
        driver_id,
        count(distinct race_id)                     as career_starts,
        -- Grand Prix wins only (fct_results excludes sprints). Distinct races
        -- so a shared drive can't double count.
        count(distinct iff(is_win, race_id, null))    as career_wins,
        count(distinct iff(is_podium, race_id, null)) as career_podiums,
        sum(points)                                 as career_points_scored,
        min(race_date)                              as first_race_date,
        max(race_date)                              as last_race_date
    from results
    group by driver_id
),

sprints as (
    select
        driver_id,
        count_if(is_win) as career_sprint_wins
    from session_results
    where session_type = 'sprint'
    group by driver_id
),

championships as (
    -- Only seasons where every scheduled race has results count.
    select
        driver_id,
        count(*) as world_championships
    from season_standings
    where is_season_complete
      and championship_position = 1
    group by driver_id
)

select
    cast(drivers.driver_id as integer)                              as driver_id,
    cast(drivers.driver_ref as varchar)                             as driver_ref,
    cast(drivers.driver_code as varchar)                            as driver_code,
    cast(drivers.permanent_number as integer)                       as current_number,
    cast(drivers.forename as varchar)                               as first_name,
    cast(drivers.surname as varchar)                                as last_name,
    cast(drivers.nationality as varchar)                            as nationality,
    cast(drivers.date_of_birth as date)                             as date_of_birth,
    cast(coalesce(career.career_starts, 0) as integer)              as career_starts,
    cast(coalesce(career.career_wins, 0) as integer)                as career_wins,
    cast(coalesce(sprints.career_sprint_wins, 0) as integer)        as career_sprint_wins,
    cast(coalesce(career.career_podiums, 0) as integer)             as career_podiums,
    cast(coalesce(career.career_points_scored, 0) as number(10, 2)) as career_points_scored,
    cast(coalesce(championships.world_championships, 0) as integer) as world_championships,
    cast(career.first_race_date as date)                            as first_race_date,
    cast(career.last_race_date as date)                             as last_race_date
from drivers
left join career
    on drivers.driver_id = career.driver_id
left join sprints
    on drivers.driver_id = sprints.driver_id
left join championships
    on drivers.driver_id = championships.driver_id
