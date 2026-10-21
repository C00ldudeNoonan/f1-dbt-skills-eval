-- One row per season: is every race on the calendar resulted, and which round is the
-- latest one with results. Basis for "completed season" (championships) and
-- "as of the latest completed round" (standings).
with races as (

    select * from {{ ref('stg_f1__races') }}

),

resulted_races as (

    select distinct race_id from {{ ref('stg_f1__results') }}

),

race_status as (

    select
        races.season,
        races.round,
        races.race_id,
        resulted_races.race_id is not null as has_results
    from races
    left join resulted_races on races.race_id = resulted_races.race_id

),

season_status as (

    select
        season,
        count(*) as calendar_race_count,
        count_if(has_results) as resulted_race_count,
        max(case when has_results then round end) as last_completed_round
    from race_status
    group by season

)

select
    season_status.season,
    season_status.calendar_race_count,
    season_status.resulted_race_count,
    season_status.calendar_race_count = season_status.resulted_race_count as is_season_complete,
    season_status.last_completed_round,
    last_race.race_id as last_completed_race_id
from season_status
left join race_status as last_race
    on season_status.season = last_race.season
    and season_status.last_completed_round = last_race.round
