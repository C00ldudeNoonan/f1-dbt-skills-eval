-- Season wins in the official standings must equal the classified wins recorded in fct_results.
-- Returns mismatching driver-seasons.
with result_wins as (

    select
        season,
        driver_id,
        count_if(is_win) as wins
    from {{ ref('fct_results') }}
    group by season, driver_id

)

select
    standings.season,
    standings.driver_id,
    standings.wins as standings_wins,
    coalesce(result_wins.wins, 0) as result_wins
from {{ ref('mart_driver_season_standings') }} as standings
left join result_wins
    on standings.season = result_wins.season
    and standings.driver_id = result_wins.driver_id
where standings.wins <> coalesce(result_wins.wins, 0)
