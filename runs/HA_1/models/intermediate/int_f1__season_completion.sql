-- A season is complete only when every Grand Prix on its calendar has results.
-- The latest completed round is the highest round that already has results.

with calendar as (

    select * from {{ ref('stg_f1__races') }}

),

races_with_results as (

    select distinct race_id from {{ ref('stg_f1__results') }}

),

calendar_status as (

    select
        calendar.season,
        calendar.round,
        races_with_results.race_id is not null as has_results
    from calendar
    left join races_with_results
        on calendar.race_id = races_with_results.race_id

)

select
    season,
    count(*) as races_on_calendar,
    count_if(has_results) as races_with_results,
    count_if(has_results) = count(*) as is_season_complete,
    max(case when has_results then round end) as latest_completed_round
from calendar_status
group by season
