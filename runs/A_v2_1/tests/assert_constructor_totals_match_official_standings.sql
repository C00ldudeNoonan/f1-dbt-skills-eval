-- Independent check on fct_session_results: for every constructor season from
-- 1979 (when every car began to score for its constructor), summed Grand Prix
-- and sprint points and Grand Prix wins must equal the published constructor
-- standings after the season's latest completed round. A join fan-out or a
-- corrupted feed inflates one team's totals (October 2026: Ferrari doubled)
-- and fails here with the team and season named. Documented FIA decisions are
-- listed in seeds/constructor_points_exceptions.csv.
with summed as (

    select
        season,
        constructor_id,
        sum(points) as summed_points,
        count_if(session_type = 'race' and is_win) as summed_wins
    from {{ ref('fct_session_results') }}
    where season >= 1979
    group by 1, 2

),

official as (

    select
        seasons.season,
        standings.constructor_id,
        standings.points as official_points,
        standings.wins as official_wins
    from {{ ref('int_seasons__completion') }} as seasons
    inner join {{ ref('stg_ergast__constructor_standings') }} as standings
        on seasons.latest_completed_race_id = standings.race_id
    where seasons.season >= 1979

),

exceptions as (

    select exceptions.season, constructors.constructor_id
    from {{ ref('constructor_points_exceptions') }} as exceptions
    inner join {{ ref('stg_ergast__constructors') }} as constructors
        on exceptions.constructor_ref = constructors.constructor_ref

)

select
    coalesce(summed.season, official.season) as season,
    coalesce(summed.constructor_id, official.constructor_id) as constructor_id,
    summed.summed_points,
    official.official_points,
    summed.summed_wins,
    official.official_wins
from summed
full outer join official
    on summed.season = official.season
    and summed.constructor_id = official.constructor_id
left join exceptions
    on coalesce(summed.season, official.season) = exceptions.season
    and coalesce(summed.constructor_id, official.constructor_id) = exceptions.constructor_id
where exceptions.constructor_id is null
    and (
        summed.summed_points is distinct from official.official_points
        or summed.summed_wins is distinct from official.official_wins
    )
