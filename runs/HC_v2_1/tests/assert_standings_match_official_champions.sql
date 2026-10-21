{#
    Every completed season from the reference seed must have the same champion and final
    points in mart_driver_season_standings. A complete season with a champion missing from
    the reference seed also fails, so the seed cannot silently fall behind the data.
#}
with official as (

    select * from {{ ref('official_season_champions') }}

),

standings_champions as (

    select
        standings.season,
        drivers.driver_ref,
        standings.points
    from {{ ref('mart_driver_season_standings') }} as standings
    inner join {{ ref('stg_f1__drivers') }} as drivers
        on standings.driver_id = drivers.driver_id
    where standings.is_season_complete
        and standings.championship_position = 1

),

mismatches as (

    select
        official.season,
        official.champion_driver_ref as expected_champion,
        standings_champions.driver_ref as actual_champion,
        official.champion_points as expected_points,
        standings_champions.points as actual_points
    from official
    left join standings_champions
        on official.season = standings_champions.season
    where standings_champions.season is null
        or standings_champions.driver_ref <> official.champion_driver_ref
        or standings_champions.points <> official.champion_points

    union all

    select
        standings_champions.season,
        null,
        standings_champions.driver_ref,
        null,
        standings_champions.points
    from standings_champions
    left join official
        on standings_champions.season = official.season
    where official.season is null

)

select * from mismatches
