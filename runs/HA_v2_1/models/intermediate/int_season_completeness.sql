{#
    A season is complete only when every race on its calendar (stg_f1__races)
    has at least one result. The latest completed round is the highest round
    with results, which is what "as of the latest completed round" means for
    standings.
#}
with races as (

    select race_id, season, round
    from {{ ref('stg_f1__races') }}

),

races_with_results as (

    select distinct race_id
    from {{ ref('stg_f1__results') }}

),

race_status as (

    select
        races.race_id,
        races.season,
        races.round,
        races_with_results.race_id is not null as has_results
    from races
    left join races_with_results
        on races.race_id = races_with_results.race_id

),

season_rollup as (

    select
        season,
        count(*) as races_on_calendar,
        count_if(has_results) as races_with_results,
        count_if(has_results) = count(*) as is_season_complete,
        max(case when has_results then round end) as latest_completed_round
    from race_status
    group by season

)

select
    season_rollup.season,
    season_rollup.races_on_calendar,
    season_rollup.races_with_results,
    season_rollup.is_season_complete,
    season_rollup.latest_completed_round,
    race_status.race_id as latest_completed_race_id
from season_rollup
inner join race_status
    on season_rollup.season = race_status.season
    and season_rollup.latest_completed_round = race_status.round
