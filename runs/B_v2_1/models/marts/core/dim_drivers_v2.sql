{#-
  dim_drivers version 2 (latest). One row per driver.
  Change from v1: full_name, forename and surname are replaced by first_name
  and last_name.

  Drivers referenced by a feed before their record lands in `drivers` get a
  placeholder row (is_placeholder = true; first_name 'Unknown', last_name
  'Driver <id>'). The model is rebuilt on every run, so the real values
  replace the placeholder as soon as the record arrives.
-#}
with driver_ids as (
    select * from {{ ref('int_driver_ids') }}
),

drivers as (
    select * from {{ ref('stg_ergast__drivers') }}
),

current_versions as (
    select driver_id, permanent_number
    from {{ ref('snp_drivers') }}
    where dbt_valid_to is null
),

career as (
    select
        driver_id,
        count(distinct race_id)                 as career_starts,
        count_if(is_win)                        as career_wins,
        count_if(is_podium)                     as career_podiums,
        min(race_date)                          as first_race_date,
        max(race_date)                          as last_race_date
    from {{ ref('fct_results') }}
    group by driver_id
),

sprint_career as (
    select
        driver_id,
        count_if(is_win) as career_sprint_wins
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
    driver_ids.driver_id,
    coalesce(drivers.driver_ref, 'unknown_driver_' || driver_ids.driver_id)    as driver_ref,
    drivers.driver_code,
    drivers.permanent_number,
    current_versions.permanent_number                                           as current_number,
    iff(driver_ids.has_driver_record, drivers.forename, 'Unknown')              as first_name,
    iff(driver_ids.has_driver_record, drivers.surname, 'Driver ' || driver_ids.driver_id) as last_name,
    drivers.nationality,
    drivers.date_of_birth,
    coalesce(career.career_starts, 0)               as career_starts,
    coalesce(career.career_wins, 0)                 as career_wins,
    coalesce(sprint_career.career_sprint_wins, 0)   as career_sprint_wins,
    coalesce(career.career_podiums, 0)              as career_podiums,
    coalesce(championships.world_championships, 0)  as world_championships,
    career.first_race_date,
    career.last_race_date,
    not driver_ids.has_driver_record                as is_placeholder
from driver_ids
left join drivers
    on driver_ids.driver_id = drivers.driver_id
left join current_versions
    on driver_ids.driver_id = current_versions.driver_id
left join career
    on driver_ids.driver_id = career.driver_id
left join sprint_career
    on driver_ids.driver_id = sprint_career.driver_id
left join championships
    on driver_ids.driver_id = championships.driver_id
