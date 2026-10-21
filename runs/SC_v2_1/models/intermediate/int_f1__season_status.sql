-- One row per season. A season is complete only when every race on its calendar
-- has results. The latest completed round is the last round that has results,
-- which is what standings are reported "as of".
with races as (

    select * from {{ ref('stg_f1__races') }}

),

races_with_results as (

    select distinct race_id from {{ ref('stg_f1__results') }}

),

flagged as (

    select
        races.season,
        races.race_id,
        races.round,
        races_with_results.race_id is not null as has_results
    from races
    left join races_with_results on races_with_results.race_id = races.race_id

)

select
    season,
    count(*) as scheduled_races,
    count_if(has_results) as races_with_results,
    max(iff(has_results, round, null)) as latest_completed_round,
    count_if(has_results) = count(*) as is_season_complete
from flagged
group by season
