{#-
  One row per season with calendar completeness.
  A round is "completed" once it has at least one Grand Prix result.
  A season is complete only when every race on its calendar is completed.
-#}
with races as (
    select * from {{ ref('stg_ergast__races') }}
),

races_with_results as (
    select distinct race_id from {{ ref('stg_ergast__results') }}
),

race_status as (
    select
        races.season,
        races.round,
        races.race_id,
        races_with_results.race_id is not null as is_completed
    from races
    left join races_with_results
        on races.race_id = races_with_results.race_id
),

seasons as (
    select
        season,
        count(*)                                            as calendar_rounds,
        count_if(is_completed)                              as completed_rounds,
        max(iff(is_completed, round, null))                 as latest_completed_round
    from race_status
    group by season
)

select
    seasons.season,
    seasons.calendar_rounds,
    seasons.completed_rounds,
    seasons.latest_completed_round,
    latest.race_id                                          as latest_completed_race_id,
    seasons.completed_rounds = seasons.calendar_rounds      as is_complete
from seasons
left join race_status as latest
    on seasons.season = latest.season
    and seasons.latest_completed_round = latest.round
