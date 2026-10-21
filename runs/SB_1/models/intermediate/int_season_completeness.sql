-- A season is complete when every race on its calendar has at least one Grand Prix result.
-- `last_completed_race_id` is the latest-round race that has results; standings as of that
-- race are the "current" standings for the season.
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
    left join races_with_results on races.race_id = races_with_results.race_id

),

season_totals as (

    select
        season,
        count(*)                as races_on_calendar,
        count_if(has_results)   as races_with_results
    from flagged
    group by season

),

last_completed as (

    select season, round as last_completed_round, race_id as last_completed_race_id
    from flagged
    where has_results
    qualify row_number() over (partition by season order by round desc) = 1

)

select
    season_totals.season,
    season_totals.races_on_calendar,
    season_totals.races_with_results,
    season_totals.races_with_results = season_totals.races_on_calendar  as is_complete,
    last_completed.last_completed_round,
    last_completed.last_completed_race_id
from season_totals
left join last_completed on season_totals.season = last_completed.season
