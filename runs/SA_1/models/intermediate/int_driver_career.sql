-- Shared career logic for every version of dim_drivers (names live in the versioned models).
with career as (
    select
        driver_id,
        count(distinct race_id)::int as career_starts,  -- distinct GPs: shared drives yield 2 result rows for one race
        count(distinct case when is_win then race_id end)::int as career_wins,
        count(distinct case when is_podium then race_id end)::int as career_podiums
    from {{ ref('fct_results') }}
    group by 1
),

sprints as (
    select
        driver_id,
        count(distinct case when is_win then race_id end)::int as career_sprint_wins
    from {{ ref('fct_session_results') }}
    where session_type = 'sprint'
    group by 1
),

champions as (
    select
        standings.driver_id,
        count(*)::int as world_championships
    from {{ ref('mart_driver_season_standings') }} as standings
    inner join {{ ref('int_season_status') }} as seasons using (season)
    where standings.championship_position = 1
      and seasons.is_complete
    group by 1
)

select
    drivers.driver_id,
    drivers.driver_ref,
    drivers.nationality,
    drivers.date_of_birth,
    coalesce(career.career_starts, 0) as career_starts,
    coalesce(career.career_wins, 0) as career_wins,
    coalesce(career.career_podiums, 0) as career_podiums,
    coalesce(sprints.career_sprint_wins, 0) as career_sprint_wins,
    coalesce(champions.world_championships, 0) as world_championships,
    drivers.current_number
from {{ ref('stg_drivers') }} as drivers
left join career using (driver_id)
left join sprints using (driver_id)
left join champions using (driver_id)
