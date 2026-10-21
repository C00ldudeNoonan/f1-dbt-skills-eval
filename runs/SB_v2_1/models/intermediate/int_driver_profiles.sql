-- Grain: one row per driver. Shared logic behind every version of the public dim_drivers model, so
-- placeholder handling and career stats are defined once.
with known_drivers as (
    select * from {{ ref('stg_f1__drivers') }}
),

-- Late-arriving drivers: ids used by the feeds but absent from the drivers table get a placeholder
-- row. Once the real record lands, the left join below picks up the real values on the next run.
drivers as (
    select
        ids.driver_id,
        coalesce(known_drivers.driver_ref, 'unknown_' || ids.driver_id) as driver_ref,
        -- invariant: full_name = first_name || ' ' || last_name, also for placeholders
        coalesce(known_drivers.full_name, 'Unknown driver ' || ids.driver_id) as full_name,
        case when known_drivers.driver_id is null then 'Unknown' else known_drivers.forename end as first_name,
        case when known_drivers.driver_id is null then 'driver ' || ids.driver_id else known_drivers.surname end as last_name,
        known_drivers.nationality,
        known_drivers.date_of_birth,
        known_drivers.permanent_number as current_number,
        known_drivers.driver_id is null as is_placeholder
    from (
        select driver_id from known_drivers
        union
        select driver_id from {{ ref('int_driver_ids') }}
    ) as ids
    left join known_drivers on known_drivers.driver_id = ids.driver_id
),

career as (
    select
        driver_id,
        count(distinct race_id)::integer as career_starts,
        count(distinct case when is_win then race_id end)::integer as career_wins,
        count(distinct case when is_podium then race_id end)::integer as career_podiums
    from {{ ref('fct_results') }}
    group by 1
),

sprints as (
    select
        driver_id,
        count(distinct race_id)::integer as career_sprint_wins
    from {{ ref('fct_session_results') }}
    where session_type = 'sprint' and is_win
    group by 1
),

titles as (
    select standings.driver_id, count(*)::integer as world_championships
    from {{ ref('mart_driver_season_standings') }} as standings
    inner join {{ ref('int_season_status') }} as status using (season)
    where standings.championship_position = 1
      and status.is_complete
    group by 1
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
    coalesce(sprints.career_sprint_wins, 0)::integer as career_sprint_wins,
    coalesce(titles.world_championships, 0)::integer as world_championships
from drivers
left join career on career.driver_id = drivers.driver_id
left join sprints on sprints.driver_id = drivers.driver_id
left join titles on titles.driver_id = drivers.driver_id
