-- Official drivers' championship standings after every completed round, one
-- row per driver per round they appear in. Taken from the published standings
-- snapshot rather than summed from results, because the official totals
-- include sprint points (2021+), dropped scores (most seasons before 1991)
-- and shared-drive splits. mart_driver_season_standings is the
-- latest-round slice of this model.

with standings as (
    select * from {{ ref('stg_f1__driver_standings') }}
),

races as (
    select * from {{ ref('int_f1__race_calendar') }}
)

select
    races.season,
    races.round,
    races.race_id,
    standings.driver_id,
    -- Null when the driver was excluded from the championship (position_text 'D').
    case when standings.position_text = standings.position::varchar then standings.position end
        as championship_position,
    standings.position_text,
    standings.points,
    standings.wins,
    races.is_latest_completed_round,
    races.is_season_complete
from standings
inner join races
    on standings.race_id = races.race_id
where races.is_completed
