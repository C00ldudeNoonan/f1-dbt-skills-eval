-- One row per season. A season is complete only when every race on its calendar has results.
-- latest_completed_race_id is the most recent round that has results, and is the point in time
-- used for season standings.
with races as (

    select * from {{ ref('stg_f1__races') }}

),

race_status as (

    select
        races.race_id,
        races.season,
        races.round,
        exists (
            select 1
            from {{ ref('stg_f1__results') }} as results
            where results.race_id = races.race_id
        ) as has_results
    from races

),

seasons as (

    select
        season,
        count(*) as calendar_races,
        count_if(has_results) as races_with_results,
        max(case when has_results then round end) as latest_completed_round
    from race_status
    group by season

)

select
    seasons.season,
    seasons.calendar_races,
    seasons.races_with_results,
    seasons.latest_completed_round,
    seasons.calendar_races = seasons.races_with_results as is_season_complete,
    latest_race.race_id as latest_completed_race_id
from seasons
left join race_status as latest_race
    on latest_race.season = seasons.season
    and latest_race.round = seasons.latest_completed_round
