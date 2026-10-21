-- Exactly one world championship is awarded per completed season.
with counts as (
    select
        (select sum(world_championships) from {{ ref('dim_drivers') }}) as championships_awarded,
        (select count(*) from {{ ref('int_season_calendar_progress') }} where is_season_complete) as completed_seasons
)

select * from counts
where championships_awarded != completed_seasons
