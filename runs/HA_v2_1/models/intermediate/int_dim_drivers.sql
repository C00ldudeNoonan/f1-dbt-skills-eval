{#
    Grain: one row per driver (driver_id). Shared by dim_drivers_v1 and dim_drivers_v2, which only
    differ in how the name is shown.
    All career counts are Grand Prix only (sprints excluded).
    world_championships counts only seasons that are complete (every calendar race has
    results), so the in-progress 2024 season does not add a title.

    career_wins counts Grand Prix wins only. career_sprint_wins counts sprint wins.

    Drivers referenced by results before their driver record arrives get a placeholder
    row (is_placeholder = true, driver_ref = 'unknown_<driver_id>', no names or numbers).
    The placeholder disappears on the run after the real record lands.
    current_number is the permanent car number from the drivers feed, null if none.
    Number and code history is in snp_drivers.
#}
with real_drivers as (

    select
        driver_id,
        driver_ref,
        forename as first_name,
        surname as last_name,
        forename || ' ' || surname as full_name,
        nationality,
        date_of_birth,
        permanent_number as current_number,
        driver_code,
        false as is_placeholder
    from {{ ref('stg_f1__drivers') }}

),

placeholder_drivers as (

    select
        driver_id,
        'unknown_' || driver_id::varchar as driver_ref,
        cast(null as varchar) as first_name,
        cast(null as varchar) as last_name,
        cast(null as varchar) as full_name,
        cast(null as varchar) as nationality,
        cast(null as date) as date_of_birth,
        cast(null as int) as current_number,
        cast(null as varchar) as driver_code,
        true as is_placeholder
    from {{ ref('int_orphan_driver_ids') }}

),

drivers as (

    select * from real_drivers
    union all
    select * from placeholder_drivers

),

career_results as (

    select
        driver_id,
        count(distinct race_id) as career_starts,
        count_if(is_win) as career_wins,
        count_if(is_podium) as career_podiums
    from {{ ref('fct_results') }}
    group by driver_id

),

sprint_wins as (

    select
        driver_id,
        count_if(finish_position = 1) as career_sprint_wins
    from {{ ref('fct_session_results') }}
    where session_type = 'sprint'
    group by driver_id

),

titles as (

    select
        driver_id,
        count(*) as world_championships
    from {{ ref('mart_driver_season_standings') }}
    where championship_position = 1
        and is_season_complete
    group by driver_id

)

select
    drivers.driver_id,
    drivers.driver_ref,
    drivers.first_name,
    drivers.last_name,
    drivers.full_name,
    drivers.nationality,
    drivers.date_of_birth,
    drivers.current_number,
    drivers.driver_code,
    drivers.is_placeholder,
    coalesce(career_results.career_starts, 0) as career_starts,
    coalesce(career_results.career_wins, 0) as career_wins,
    coalesce(career_results.career_podiums, 0) as career_podiums,
    coalesce(sprint_wins.career_sprint_wins, 0) as career_sprint_wins,
    coalesce(titles.world_championships, 0) as world_championships
from drivers
left join career_results
    on drivers.driver_id = career_results.driver_id
left join sprint_wins
    on drivers.driver_id = sprint_wins.driver_id
left join titles
    on drivers.driver_id = titles.driver_id
