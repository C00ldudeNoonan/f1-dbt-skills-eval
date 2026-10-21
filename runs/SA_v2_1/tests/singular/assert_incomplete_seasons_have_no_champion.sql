-- A championship only counts once every race on the calendar has results.
select season
from {{ ref('int_season_status') }}
where not is_season_complete
    and season in (
        select season
        from {{ ref('mart_driver_season_standings') }}
        where is_season_complete
    )
