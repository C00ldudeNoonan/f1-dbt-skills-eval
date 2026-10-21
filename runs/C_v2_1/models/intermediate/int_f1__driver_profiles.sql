-- One row per driver (plus a placeholder per late-arriving driver_id) with
-- career totals. Shared by every version of dim_drivers, so versions only
-- differ in the columns they expose. Placeholder names are built so that
-- first_name || ' ' || last_name always equals full_name.

with known_drivers as (
    select
        *,
        forename as first_name,
        surname as last_name,
        false as is_placeholder
    from {{ ref('stg_f1__drivers') }}
),

placeholder_drivers as (
    -- Results can arrive before the driver's record (rookies, reserves).
    -- Those drivers get a placeholder so facts referencing them still join.
    -- The table is rebuilt every run, so the real values replace the
    -- placeholder as soon as the record lands.
    select
        driver_id,
        'unknown_driver_' || driver_id as driver_ref,
        null::integer as permanent_number,
        null::varchar as driver_code,
        null::varchar as forename,
        null::varchar as surname,
        'Unknown' as first_name,
        'driver (id ' || driver_id || ')' as last_name,
        'Unknown driver (id ' || driver_id || ')' as full_name,
        null::date as date_of_birth,
        null::varchar as nationality,
        null::varchar as wikipedia_url,
        true as is_placeholder
    from {{ ref('mon_late_arriving_drivers') }}
),

drivers as (
    select
        driver_id, driver_ref, permanent_number, driver_code, forename, surname,
        first_name, last_name, full_name, date_of_birth, nationality, wikipedia_url,
        is_placeholder
    from known_drivers
    union all
    select
        driver_id, driver_ref, permanent_number, driver_code, forename, surname,
        first_name, last_name, full_name, date_of_birth, nationality, wikipedia_url,
        is_placeholder
    from placeholder_drivers
),

results as (
    select * from {{ ref('fct_results') }}
),

sprint_results as (
    select
        driver_id,
        count_if(is_win) as career_sprint_wins
    from {{ ref('fct_session_results') }}
    where session_type = 'sprint'
    group by driver_id
),

standings as (
    select * from {{ ref('mart_driver_season_standings') }}
),

career_results as (
    -- Before 1979 a driver can have several result rows (shared cars) in one
    -- race. Starts count each Grand Prix once; wins and podiums count each
    -- classification, matching official records (Farina has 20 podiums,
    -- two of them in the shared-car 1955 Argentine GP).
    select
        driver_id,
        count(distinct race_id) as career_starts,
        count_if(is_win) as career_wins,
        count_if(is_podium) as career_podiums,
        min(race_date) as first_race_date,
        max(race_date) as last_race_date
    from results
    group by driver_id
),

championships as (
    select
        driver_id,
        count(*) as world_championships
    from standings
    where championship_position = 1
        and is_season_complete
    group by driver_id
)

select
    drivers.driver_id,
    drivers.driver_ref,
    drivers.driver_code,
    drivers.permanent_number,
    -- Raw drivers holds only current values, so this is the driver's number
    -- today. Earlier values are in snp_drivers.
    drivers.permanent_number as current_number,
    drivers.full_name,
    drivers.first_name,
    drivers.last_name,
    drivers.forename,
    drivers.surname,
    drivers.nationality,
    drivers.date_of_birth,
    coalesce(career_results.career_starts, 0) as career_starts,
    coalesce(career_results.career_wins, 0) as career_wins,
    coalesce(sprint_results.career_sprint_wins, 0) as career_sprint_wins,
    coalesce(career_results.career_podiums, 0) as career_podiums,
    coalesce(championships.world_championships, 0) as world_championships,
    career_results.first_race_date,
    career_results.last_race_date,
    drivers.is_placeholder
from drivers
left join career_results
    on drivers.driver_id = career_results.driver_id
left join sprint_results
    on drivers.driver_id = sprint_results.driver_id
left join championships
    on drivers.driver_id = championships.driver_id
