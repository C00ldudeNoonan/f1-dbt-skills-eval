-- One row per season. A season is complete only when every race on its calendar has results.
-- (The current/most recent season may list future races that have not been run yet.)
with races as (
    select * from {{ ref('stg_races') }}
),

results_per_race as (
    select race_id, count(*) as result_count
    from {{ ref('stg_results') }}
    group by 1
)

select
    races.season,
    count(*) as races_on_calendar,
    count(results_per_race.race_id) as races_with_results,
    max(case when results_per_race.race_id is not null then races.round end) as last_completed_round,
    count(*) = count(results_per_race.race_id) as is_complete
from races
left join results_per_race using (race_id)
group by 1
