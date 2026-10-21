-- Official standings can drop scores, but never exceed what a driver scored in results + sprints
-- (a leak here would indicate a wrong round or duplicated standings rows).
-- Sprint points live only in the raw sprint table, so compare to results alone with tolerance
-- for sprint seasons by checking only seasons without sprints.
with sprint_seasons as (
    select distinct races.season
    from {{ source('f1_raw', 'sprint_results') }} as sprints
    inner join {{ ref('stg_races') }} as races on races.race_id = sprints.raceid::int
),

scored as (
    select races.season, results.driver_id, sum(results.points) as race_points
    from {{ ref('stg_results') }} as results
    inner join {{ ref('stg_races') }} as races using (race_id)
    group by 1, 2
)

select standings.season, standings.driver_id, standings.points, scored.race_points
from {{ ref('mart_driver_season_standings') }} as standings
left join scored using (season, driver_id)
where standings.season not in (select season from sprint_seasons)
  and standings.points > coalesce(scored.race_points, 0) + 0.001
