-- Driver attributes plus career aggregates, shared by every version of dim_drivers so the
-- versions differ only in how they present names.
with drivers as (

    select * from {{ ref('stg_f1__drivers') }}

),

career as (

    select
        driver_id,
        -- distinct races: early shared drives give one race several rows per driver
        count(distinct race_id) as career_starts,
        count(distinct case when status not in ('Did not qualify', 'Did not prequalify') then race_id end)
            as career_race_entries_excl_dnq,
        count(distinct case when is_win then race_id end) as career_wins,
        count(distinct case when is_podium then race_id end) as career_podiums
    from {{ ref('fct_results') }}
    group by driver_id

),

sprint_wins as (

    select
        driver_id,
        count(*) as career_sprint_wins
    from {{ ref('fct_session_results') }}
    where session_type = 'sprint'
        and is_win
    group by driver_id

),

titles as (

    select
        standings.driver_id,
        count(*) as world_championships
    from {{ ref('mart_driver_season_standings') }} as standings
    where standings.championship_position = 1
        and standings.is_season_complete
    group by standings.driver_id

)

select
    drivers.driver_id,
    drivers.driver_ref,
    drivers.driver_number as current_number,
    drivers.forename as first_name,
    drivers.surname as last_name,
    drivers.nationality,
    drivers.date_of_birth,
    coalesce(career.career_starts, 0) as career_starts,
    coalesce(career.career_race_entries_excl_dnq, 0) as career_race_entries_excl_dnq,
    coalesce(career.career_wins, 0) as career_wins,
    coalesce(career.career_podiums, 0) as career_podiums,
    coalesce(sprint_wins.career_sprint_wins, 0) as career_sprint_wins,
    coalesce(titles.world_championships, 0) as world_championships
from drivers
left join career on drivers.driver_id = career.driver_id
left join sprint_wins on drivers.driver_id = sprint_wins.driver_id
left join titles on drivers.driver_id = titles.driver_id
