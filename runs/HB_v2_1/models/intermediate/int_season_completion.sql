{#
    One row per season describing how far the season has been completed.
    A season counts as complete only when every race on its calendar has
    results. The latest completed round is the last round before the first
    round with no results (for an incomplete season) or the final round.
#}
with races as (

    select
        race_id,
        season,
        round,
        race_id in (select race_id from {{ ref('stg_f1__results') }}) as has_results

    from {{ ref('stg_f1__races') }}

),

season_summary as (

    select
        season,
        count(*) as calendar_races,
        count_if(has_results) as races_with_results,
        min(case when not has_results then round end) as first_missing_round

    from races
    group by season

),

completed_races as (

    select
        races.season,
        races.race_id,
        races.round

    from races
    inner join season_summary
        on races.season = season_summary.season
    where races.has_results
        and (
            season_summary.first_missing_round is null
            or races.round < season_summary.first_missing_round
        )

),

latest_completed as (

    select
        season,
        max_by(race_id, round) as latest_completed_race_id,
        max(round) as latest_completed_round

    from completed_races
    group by season

)

select
    season_summary.season,
    season_summary.calendar_races,
    season_summary.races_with_results,
    season_summary.first_missing_round,
    season_summary.first_missing_round is null as is_season_complete,
    latest_completed.latest_completed_race_id,
    latest_completed.latest_completed_round

from season_summary
left join latest_completed
    on season_summary.season = latest_completed.season
