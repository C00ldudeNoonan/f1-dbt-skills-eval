-- Every published champion from 1950 to 2023 must be the only title holder for that season in
-- the standings mart, and no other champion may appear in those seasons. Returns failing rows.
with reference as (

    select * from {{ ref('world_champions_reference') }}

),

champions as (

    select
        standings.season,
        drivers.driver_ref
    from {{ ref('mart_driver_season_standings') }} as standings
    inner join {{ ref('stg_ergast__drivers') }} as drivers
        on standings.driver_id = drivers.driver_id
    where standings.is_champion

),

missing_from_standings as (

    select
        reference.season,
        reference.driver_ref,
        'published champion not flagged in standings' as problem
    from reference
    left join champions
        on reference.season = champions.season
        and reference.driver_ref = champions.driver_ref
    where champions.driver_ref is null

),

unexpected_champions as (

    select
        champions.season,
        champions.driver_ref,
        'flagged champion does not match published record' as problem
    from champions
    left join reference
        on champions.season = reference.season
        and champions.driver_ref = reference.driver_ref
    where reference.driver_ref is null
        and champions.season <= 2023

)

select * from missing_from_standings
union all
select * from unexpected_champions
