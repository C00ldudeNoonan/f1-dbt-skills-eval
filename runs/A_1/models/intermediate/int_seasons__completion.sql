{#
  One row per season: how much of the calendar has been run.

  A round is "completed" when it has at least one Grand Prix result. A season is
  complete only when every round on its calendar is completed — this is what
  gates world championships, so a season in progress (e.g. 2024 in the current
  load, 22 of 24 rounds) never awards a title.
#}

with races as (
    select * from {{ ref('stg_ergast__races') }}
),

races_with_results as (
    select distinct race_id from {{ ref('stg_ergast__results') }}
),

rounds as (
    select
        races.season,
        races.round,
        races.race_id,
        races_with_results.race_id is not null as is_completed
    from races
    left join races_with_results
        on races.race_id = races_with_results.race_id
)

select
    season,
    count(*)                                            as scheduled_rounds,
    count_if(is_completed)                              as completed_rounds,
    max(iff(is_completed, round, null))                 as latest_completed_round,
    max_by(iff(is_completed, race_id, null), iff(is_completed, round, null)) as latest_completed_race_id,
    count(*) = count_if(is_completed)                   as is_complete
from rounds
group by season
