-- Career counts are per distinct Grand Prix (race_id), not per result row: a driver can have
-- two result rows in one race when sharing cars.
with drivers as (

    select * from {{ ref('stg_f1__drivers') }}

),

career as (

    select
        driver_id,
        count(distinct race_id)                          as career_starts,
        count(distinct case when is_win then race_id end)    as career_wins,
        count(distinct case when is_podium then race_id end) as career_podiums
    from {{ ref('fct_results') }}
    group by driver_id

),

sprint_wins as (

    select
        driver_id,
        count(distinct race_id) as career_sprint_wins
    from {{ ref('fct_session_results') }}
    where session_type = 'sprint' and is_win
    group by driver_id

),

titles as (

    select
        standings.driver_id,
        count(*) as world_championships
    from {{ ref('mart_driver_season_standings') }} as standings
    inner join {{ ref('int_season_completeness') }} as seasons
        on standings.season = seasons.season
    where standings.championship_position = 1
      and seasons.is_complete
    group by standings.driver_id

)

select
    drivers.driver_id,
    drivers.driver_ref,
    drivers.forename                                         as first_name,
    drivers.surname                                          as last_name,
    drivers.nationality,
    drivers.date_of_birth,
    drivers.permanent_number                                 as current_number,
    coalesce(career.career_starts, 0)::number(18, 0)         as career_starts,
    coalesce(career.career_wins, 0)::number(18, 0)           as career_wins,
    coalesce(career.career_podiums, 0)::number(18, 0)        as career_podiums,
    coalesce(sprint_wins.career_sprint_wins, 0)::number(18, 0) as career_sprint_wins,
    coalesce(titles.world_championships, 0)::number(18, 0)   as world_championships
from drivers
left join career on drivers.driver_id = career.driver_id
left join sprint_wins on drivers.driver_id = sprint_wins.driver_id
left join titles on drivers.driver_id = titles.driver_id
