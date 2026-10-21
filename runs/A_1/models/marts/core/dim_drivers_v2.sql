{#
  dim_drivers, version 2 (latest). One row per driver with career aggregates.
  PUBLIC, CONTRACTED interface — consumed by other dbt projects. Column names
  and types are enforced by the contract in _core__models.yml; changing them
  requires a new version.

  v2 vs v1: full_name / forename / surname are replaced by first_name and
  last_name. v1 (dim_drivers_v1.sql) is a projection of this model.

  - career_starts counts DISTINCT Grands Prix entered, so a 1950s driver who
    shared two cars in one race counts that race once. Every results row is an
    entry (including did-not-qualify entries).
  - career_wins / career_podiums likewise count distinct races, Grands Prix
    only. Sprint wins are reported separately as career_sprint_wins.
  - current_number is the driver's permanent car number as of the latest load
    (null if they never had one — numbers were only made permanent in 2014).
    Past numbers/codes are in the snp_drivers snapshot.
  - world_championships counts seasons the driver finished P1 in the final
    standings, for complete seasons only (see int_seasons__completion).
#}

with drivers as (
    select * from {{ ref('stg_ergast__drivers') }}
),

results as (
    select * from {{ ref('fct_results') }}
),

session_results as (
    select * from {{ ref('fct_session_results') }}
),

standings as (
    select * from {{ ref('mart_driver_season_standings') }}
),

seasons as (
    select * from {{ ref('int_seasons__completion') }}
),

career as (
    select
        driver_id,
        count(distinct race_id)                             as career_starts,
        count(distinct iff(is_win, race_id, null))          as career_wins,
        count(distinct iff(is_podium, race_id, null))       as career_podiums,
        sum(points)                                         as career_points_scored,
        min(season)                                         as first_season,
        max(season)                                         as last_season
    from results
    group by driver_id
),

sprints as (
    select
        driver_id,
        count(distinct iff(is_win, race_id, null))          as career_sprint_wins
    from session_results
    where session_type = 'sprint'
    group by driver_id
),

championships as (
    select
        standings.driver_id,
        count(*) as world_championships
    from standings
    inner join seasons
        on standings.season = seasons.season
    where seasons.is_complete
      and standings.championship_position = 1
    group by standings.driver_id
)

select
    drivers.driver_id::integer                                  as driver_id,
    drivers.driver_ref::varchar                                 as driver_ref,
    drivers.forename::varchar                                   as first_name,
    drivers.surname::varchar                                    as last_name,
    drivers.driver_code::varchar                                as driver_code,
    drivers.permanent_number::integer                           as current_number,
    drivers.nationality::varchar                                as nationality,
    drivers.date_of_birth::date                                 as date_of_birth,
    coalesce(career.career_starts, 0)::integer                  as career_starts,
    coalesce(career.career_wins, 0)::integer                    as career_wins,
    coalesce(career.career_podiums, 0)::integer                 as career_podiums,
    coalesce(championships.world_championships, 0)::integer     as world_championships,
    career.career_points_scored::number(12, 2)                  as career_points_scored,
    career.first_season::integer                                as first_season,
    career.last_season::integer                                 as last_season,
    coalesce(sprints.career_sprint_wins, 0)::integer            as career_sprint_wins
from drivers
left join career
    on drivers.driver_id = career.driver_id
left join sprints
    on drivers.driver_id = sprints.driver_id
left join championships
    on drivers.driver_id = championships.driver_id
