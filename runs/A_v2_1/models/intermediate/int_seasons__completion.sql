-- One row per season: how much of the calendar has been run, and the latest
-- completed round. A round is completed when it has at least one result row.
with races as (

    select * from {{ ref('stg_ergast__races') }}

),

races_with_results as (

    select distinct race_id from {{ ref('stg_ergast__results') }}

),

flagged as (

    select
        races.season,
        races.round,
        races.race_id,
        races_with_results.race_id is not null as has_results
    from races
    left join races_with_results
        on races.race_id = races_with_results.race_id

)

select
    season,
    count(*) as scheduled_races,
    count_if(has_results) as completed_races,
    count_if(has_results) = count(*) as is_season_complete,
    max(iff(has_results, round, null)) as latest_completed_round,
    max_by(iff(has_results, race_id, null), iff(has_results, round, null)) as latest_completed_race_id
from flagged
group by season
