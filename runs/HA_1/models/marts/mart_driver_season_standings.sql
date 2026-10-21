-- Official driver championship standings as of each season's latest completed round.
-- Derived from mart_driver_standings_by_round; the season completion flag comes from int_f1__season_completion.

with completion as (

    select * from {{ ref('int_f1__season_completion') }}
    where latest_completed_round is not null

)

select
    standings.season,
    completion.latest_completed_round,
    completion.is_season_complete,
    standings.driver_id,
    standings.championship_position,
    standings.points,
    standings.wins
from {{ ref('mart_driver_standings_by_round') }} as standings
inner join completion
    on standings.season = completion.season
    and standings.round = completion.latest_completed_round
