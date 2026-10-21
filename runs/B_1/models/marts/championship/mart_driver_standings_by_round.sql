{#
    Official drivers' championship standings after every round: one row per
    driver per round they appear in the standings. Use it to chart how a
    championship evolved. Points include sprints and, before 1991, already
    apply dropped-score rules, exactly as officially published at the time.
#}

with standings as (
    select * from {{ ref('stg_ergast__driver_standings') }}
),

races as (
    select * from {{ ref('stg_ergast__races') }}
),

drivers as (
    select * from {{ ref('stg_ergast__drivers') }}
)

select
    races.season,
    races.round,
    standings.race_id,
    races.race_date,
    standings.driver_id,
    drivers.driver_ref,
    drivers.full_name,
    -- An excluded driver keeps their points but holds no championship position.
    iff(standings.is_excluded_from_championship, null, standings.position)
                                                as championship_position,
    standings.points,
    standings.wins,
    standings.is_excluded_from_championship
from standings
inner join races
    on standings.race_id = races.race_id
left join drivers
    on standings.driver_id = drivers.driver_id
