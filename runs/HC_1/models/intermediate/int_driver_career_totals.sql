-- Career totals per driver, shared by every version of dim_drivers.
-- Race totals come from fct_results, sprint wins from fct_session_results, titles from the
-- season standings (complete seasons only).
with career_results as (

    select
        driver_id,
        count(distinct case when is_race_start then race_id end) as career_starts,
        count_if(is_win) as career_wins,
        count_if(is_podium) as career_podiums
    from {{ ref('fct_results') }}
    group by 1

),

sprint_wins as (

    select
        driver_id,
        count_if(finish_position = 1) as career_sprint_wins
    from {{ ref('fct_session_results') }}
    where session_type = 'sprint'
    group by 1

),

titles as (

    select
        driver_id,
        count_if(is_champion) as world_championships
    from {{ ref('mart_driver_season_standings') }}
    group by 1

),

drivers as (

    select driver_id from {{ ref('stg_ergast__drivers') }}

)

select
    drivers.driver_id,
    coalesce(career_results.career_starts, 0)::number as career_starts,
    coalesce(career_results.career_wins, 0)::number as career_wins,
    coalesce(career_results.career_podiums, 0)::number as career_podiums,
    coalesce(sprint_wins.career_sprint_wins, 0)::number as career_sprint_wins,
    coalesce(titles.world_championships, 0)::number as world_championships
from drivers
left join career_results
    on drivers.driver_id = career_results.driver_id
left join sprint_wins
    on drivers.driver_id = sprint_wins.driver_id
left join titles
    on drivers.driver_id = titles.driver_id
