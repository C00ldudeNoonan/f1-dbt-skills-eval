{#
    One row per driver per season, as of the latest round with standings data. It is derived from
    mart_driver_standings_by_round. is_season_complete is false for seasons that still have calendar races
    without results. Those standings are correct as of as_of_round, but they are not final.
#}
with latest_round as (

    select *
    from {{ ref('mart_driver_standings_by_round') }}
    qualify round = max(round) over (partition by season)

)

select
    latest_round.season,
    latest_round.driver_id,
    latest_round.championship_position,
    latest_round.points,
    latest_round.wins,
    latest_round.round as as_of_round,
    completeness.is_season_complete
from latest_round
inner join {{ ref('int_season_completeness') }} as completeness
    on latest_round.season = completeness.season
