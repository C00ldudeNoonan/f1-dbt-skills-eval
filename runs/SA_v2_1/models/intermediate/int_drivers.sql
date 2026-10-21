-- Shared logic behind every version of dim_drivers (v1 derives full_name, v2 exposes first/last name).
-- Placeholder rows have no first_name and an 'Unknown driver (<id>)' last_name.
-- career_wins/podiums are Grand Prix only; sprint wins are separate. Counts are distinct Grands Prix: in the 1950s a driver could have two
-- result rows in one race (shared drives), which must count once.
--
-- Late-arriving drivers: a driver_id can show up in the results/qualifying/lap/pit/standings
-- feeds before its record lands in `drivers`. Those ids get a placeholder row
-- (is_placeholder = true) so every fact keeps a valid driver_id; once the real record
-- arrives the next run replaces the placeholder with the real values automatically.
with career as (

    select
        driver_id,
        count(distinct race_id) as career_starts,
        count(distinct case when is_win then race_id end) as career_wins,
        count(distinct case when is_podium then race_id end) as career_podiums
    from {{ ref('fct_results') }}
    group by driver_id

),

sprint_career as (

    select
        driver_id,
        count(distinct case when is_win then race_id end) as career_sprint_wins
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

),

known_drivers as (

    select
        driver_id,
        driver_ref,
        forename as first_name,
        surname as last_name,
        nationality,
        date_of_birth,
        driver_number as current_number,
        false as is_placeholder
    from {{ ref('stg_ergast__drivers') }}

),

referenced_driver_ids as (

    select driver_id from {{ ref('stg_ergast__results') }}
    union
    select driver_id from {{ ref('stg_ergast__sprint_results') }}
    union
    select driver_id from {{ ref('stg_ergast__qualifying') }}
    union
    select driver_id from {{ ref('stg_ergast__lap_times') }}
    union
    select driver_id from {{ ref('stg_ergast__pit_stops') }}
    union
    select driver_id from {{ ref('stg_ergast__driver_standings') }}

),

placeholder_drivers as (

    select
        driver_id,
        'unknown_' || driver_id as driver_ref,
        null as first_name,
        'Unknown driver (' || driver_id || ')' as last_name,
        null as nationality,
        null::date as date_of_birth,
        null::integer as current_number,
        true as is_placeholder
    from referenced_driver_ids
    where driver_id not in (select driver_id from known_drivers)

),

drivers as (

    select * from known_drivers
    union all
    select * from placeholder_drivers

)

select
    drivers.driver_id,
    drivers.driver_ref,
    drivers.first_name,
    drivers.last_name,
    drivers.nationality,
    drivers.date_of_birth,
    drivers.current_number,
    drivers.is_placeholder,
    coalesce(career.career_starts, 0) as career_starts,
    coalesce(career.career_wins, 0) as career_wins,
    coalesce(career.career_podiums, 0) as career_podiums,
    coalesce(sprint_career.career_sprint_wins, 0) as career_sprint_wins,
    coalesce(championships.world_championships, 0) as world_championships
from drivers
left join career on drivers.driver_id = career.driver_id
left join sprint_career on drivers.driver_id = sprint_career.driver_id
left join championships on drivers.driver_id = championships.driver_id
