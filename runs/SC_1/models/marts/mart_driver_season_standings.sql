-- Official standings as of each season's latest completed round: the by-round table filtered
-- to that round. Points come from the official standings, not re-summed from results
-- (historic seasons dropped worst results, so summed points disagree with the official table).
with season_status as (

    select * from {{ ref('int_f1__season_status') }}

),

standings_by_round as (

    select * from {{ ref('mart_driver_standings_by_round') }}

)

select
    standings_by_round.season,
    standings_by_round.driver_id,
    standings_by_round.championship_position,
    standings_by_round.points,
    standings_by_round.wins,
    season_status.last_completed_round as as_of_round,
    season_status.is_season_complete
from standings_by_round
inner join season_status
    on standings_by_round.race_id = season_status.last_completed_race_id
