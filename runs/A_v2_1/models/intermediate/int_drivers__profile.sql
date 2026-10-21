-- One row per known driver (real records plus late-arriving placeholders) with
-- career totals. Shared logic behind every version of dim_drivers, which only
-- choose and type the published columns.
with spine as (

    select * from {{ ref('int_drivers__spine') }}

),

drivers as (

    select * from {{ ref('stg_ergast__drivers') }}

),

results as (

    select * from {{ ref('fct_results') }}

),

standings as (

    select * from {{ ref('mart_driver_season_standings') }}

),

career as (

    select
        driver_id,
        count(distinct race_id) as career_starts,
        -- Distinct races, so a shared-drive win counts once per driver.
        count(distinct iff(is_win, race_id, null)) as career_wins,
        count(distinct iff(is_podium, race_id, null)) as career_podiums,
        sum(points) as career_points,
        min(season) as first_season,
        max(season) as last_season
    from results
    group by driver_id

),

sprints as (

    select
        driver_id,
        count(distinct iff(is_win, race_id, null)) as career_sprint_wins
    from {{ ref('fct_session_results') }}
    where session_type = 'sprint'
    group by driver_id

),

championships as (

    -- Only seasons whose whole calendar has results can award a title.
    select
        driver_id,
        count(*) as world_championships
    from standings
    where championship_position = 1
        and is_season_complete
    group by driver_id

)

-- Placeholder rows (driver record not arrived yet) get recognisable defaults;
-- the next run after the record lands picks up the real values.
select
    spine.driver_id,
    spine.is_placeholder,
    coalesce(drivers.driver_ref, 'unknown_driver_' || spine.driver_id) as driver_ref,
    drivers.driver_code,
    drivers.permanent_number as current_number,
    drivers.forename,
    drivers.surname,
    coalesce(drivers.full_name, 'Unknown driver ' || spine.driver_id) as full_name,
    drivers.nationality,
    drivers.date_of_birth,
    career.first_season,
    career.last_season,
    coalesce(career.career_starts, 0) as career_starts,
    coalesce(career.career_wins, 0) as career_wins,
    coalesce(sprints.career_sprint_wins, 0) as career_sprint_wins,
    coalesce(career.career_podiums, 0) as career_podiums,
    coalesce(career.career_points, 0) as career_points,
    coalesce(championships.world_championships, 0) as world_championships,
    drivers.url
from spine
left join drivers
    on spine.driver_id = drivers.driver_id
left join career
    on spine.driver_id = career.driver_id
left join sprints
    on spine.driver_id = sprints.driver_id
left join championships
    on spine.driver_id = championships.driver_id
