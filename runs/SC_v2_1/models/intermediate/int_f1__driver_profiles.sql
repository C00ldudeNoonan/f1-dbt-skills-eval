-- Shared driver profile logic behind every version of dim_drivers, so versions differ only
-- in their column shape and never in their numbers.
with drivers as (

    select * from {{ ref('int_f1__drivers_with_placeholders') }}

),

career as (

    select
        driver_id,
        count(distinct race_id) as career_starts,
        -- shared drives can put one driver on two result rows in a race
        count(distinct iff(is_win, race_id, null)) as career_wins,
        count(distinct iff(is_podium, race_id, null)) as career_podiums
    from {{ ref('fct_results') }}
    group by driver_id

),

sprint_career as (

    select
        driver_id,
        count(distinct iff(finish_position = 1, race_id, null)) as career_sprint_wins
    from {{ ref('fct_session_results') }}
    where session_type = 'sprint'
    group by driver_id

),

championships as (

    select
        driver_id,
        count(*) as world_championships
    from {{ ref('mart_driver_season_standings') }}
    where championship_position = 1
        and is_season_complete
    group by driver_id

)

select
    drivers.driver_id,
    drivers.driver_ref,
    drivers.full_name,
    drivers.first_name,
    drivers.last_name,
    drivers.nationality,
    drivers.date_of_birth,
    drivers.current_number,
    drivers.is_placeholder,
    coalesce(career.career_starts, 0)::integer as career_starts,
    coalesce(career.career_wins, 0)::integer as career_wins,
    coalesce(career.career_podiums, 0)::integer as career_podiums,
    coalesce(sprint_career.career_sprint_wins, 0)::integer as career_sprint_wins,
    coalesce(championships.world_championships, 0)::integer as world_championships
from drivers
left join career on career.driver_id = drivers.driver_id
left join sprint_career on sprint_career.driver_id = drivers.driver_id
left join championships on championships.driver_id = drivers.driver_id
