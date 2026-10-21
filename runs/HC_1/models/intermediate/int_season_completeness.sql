-- One row per season. A season is complete only when every race on its calendar has
-- results; championships and "latest round" standings depend on this.
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
        races_with_results.race_id is not null as has_results
    from races
    left join races_with_results using (race_id)

),

seasons as (

    select
        season,
        count(*) as races_on_calendar,
        count_if(has_results) as races_with_results,
        min(case when not has_results then round end) as first_round_without_results,
        max(round) as final_round
    from race_status
    group by season

)

select
    season,
    races_on_calendar,
    races_with_results,
    races_with_results = races_on_calendar as is_season_complete,
    -- Latest round where every round up to it has results.
    coalesce(first_round_without_results - 1, final_round) as latest_completed_round
from seasons
