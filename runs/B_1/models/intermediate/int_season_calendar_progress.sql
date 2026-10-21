{#
    Season-level completeness. A season is complete only once every race on
    its calendar has Grand Prix results; the latest completed round is the
    highest round that has results.
#}

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
),

latest_completed as (
    select
        season,
        race_id as latest_completed_race_id,
        round as latest_completed_round
    from flagged
    where has_results
    qualify row_number() over (partition by season order by round desc) = 1
)

select
    flagged.season,
    count(*)                                    as scheduled_rounds,
    count_if(flagged.has_results)               as completed_rounds,
    count(*) = count_if(flagged.has_results)    as is_season_complete,
    latest_completed.latest_completed_round,
    latest_completed.latest_completed_race_id
from flagged
left join latest_completed
    on flagged.season = latest_completed.season
group by
    flagged.season,
    latest_completed.latest_completed_round,
    latest_completed.latest_completed_race_id
