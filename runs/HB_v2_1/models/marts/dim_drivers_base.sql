{#
    Shared logic behind every version of dim_drivers. Holds the real drivers plus a
    placeholder row for each driver_id that race data references before its record arrives
    (is_placeholder = true). Placeholders keep their career stats. This model is not public:
    consumers use dim_drivers, which exposes one version per contract.

    career_wins and career_podiums count Grands Prix only. career_sprint_wins counts sprints.
    world_championships counts only complete seasons.
    current_number is the permanent car number, null when there is none.
#}
with real_drivers as (

    select
        driver_id,
        driver_ref,
        driver_number as current_number,
        driver_code,
        forename as first_name,
        surname as last_name,
        nationality,
        date_of_birth,
        false as is_placeholder

    from {{ ref('stg_f1__drivers') }}

),

placeholder_drivers as (

    select
        driver_id,
        'unknown_' || driver_id::string as driver_ref,
        null::integer as current_number,
        null::string as driver_code,
        null::string as first_name,
        'Unknown driver ' || driver_id::string as last_name,
        null::string as nationality,
        null::date as date_of_birth,
        true as is_placeholder

    from {{ ref('int_orphan_driver_ids') }}

),

drivers as (

    select * from real_drivers
    union all
    select * from placeholder_drivers

),

results as (

    select
        driver_id,
        race_id,
        is_win,
        is_podium

    from {{ ref('fct_results') }}

),

career as (

    select
        driver_id,
        count(distinct race_id) as career_starts,
        count_if(is_win) as career_wins,
        count_if(is_podium) as career_podiums

    from results
    group by driver_id

),

sprint_wins as (

    select
        driver_id,
        count_if(is_win) as career_sprint_wins

    from {{ ref('fct_session_results') }}
    where session_type = 'sprint'
    group by driver_id

),

titles as (

    select
        driver_id,
        count(*) as world_championships

    from {{ ref('mart_driver_season_standings') }}
    where is_champion
        and is_season_complete
    group by driver_id

)

select
    drivers.driver_id,
    drivers.driver_ref,
    drivers.current_number,
    drivers.driver_code,
    drivers.first_name,
    drivers.last_name,
    drivers.nationality,
    drivers.date_of_birth,
    drivers.is_placeholder,
    coalesce(career.career_starts, 0) as career_starts,
    coalesce(career.career_wins, 0) as career_wins,
    coalesce(career.career_podiums, 0) as career_podiums,
    coalesce(sprint_wins.career_sprint_wins, 0) as career_sprint_wins,
    coalesce(titles.world_championships, 0) as world_championships

from drivers
left join career
    on drivers.driver_id = career.driver_id
left join sprint_wins
    on drivers.driver_id = sprint_wins.driver_id
left join titles
    on drivers.driver_id = titles.driver_id
