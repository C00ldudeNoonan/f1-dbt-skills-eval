-- One row per season: how far through the calendar the results go.
-- A season is complete only when every race on its calendar has at least one result row.
with races as (
    select race_id, season, round from {{ ref('stg_f1__races') }}
),

results_per_race as (
    select race_id, count(*) as result_rows
    from {{ ref('stg_f1__results') }}
    group by 1
),

joined as (
    select
        races.season,
        races.race_id,
        races.round,
        results_per_race.race_id is not null as has_results
    from races
    left join results_per_race on results_per_race.race_id = races.race_id
)

select
    season,
    count(*) as races_scheduled,
    count_if(has_results) as races_with_results,
    max(case when has_results then round end) as last_completed_round,
    max_by(race_id, case when has_results then round end) as last_completed_race_id,
    count_if(has_results) = count(*) as is_complete
from joined
group by 1
