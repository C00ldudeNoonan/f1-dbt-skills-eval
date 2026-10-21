-- Every sprint held has exactly one classified winner, so career sprint wins
-- across all drivers equal the number of sprints.
select
    (select count(distinct race_id) from {{ ref('fct_session_results') }} where session_type = 'sprint') as sprints_held,
    (select sum(career_sprint_wins) from {{ ref('dim_drivers') }}) as sprint_wins_awarded
where sprints_held != sprint_wins_awarded
