-- One row per season: whether every race on the calendar has results, and the last
-- round that does. Standings and championships key off this, so a season that is
-- still in progress (or has a truncated load, like 2024 here) is never treated as final.
with races as (

    select * from {{ ref('stg_ergast__races') }}

),

results_per_race as (

    select race_id, count(*) as result_count
    from {{ ref('stg_ergast__results') }}
    group by race_id

),

race_status as (

    select
        races.season,
        races.round,
        races.race_id,
        coalesce(results_per_race.result_count, 0) > 0 as has_results
    from races
    left join results_per_race on results_per_race.race_id = races.race_id

)

select
    season,
    count(*) as races_on_calendar,
    count_if(has_results) as races_with_results,
    count_if(has_results) = count(*) as is_season_complete,
    max(case when has_results then round end) as last_completed_round,
    max_by(race_id, case when has_results then round end) as last_completed_race_id
from race_status
group by season
