-- Every season on the calendar must have standings as of its latest completed round.
-- Returns seasons with no standings rows.
select
    completeness.season
from {{ ref('int_season_completeness') }} as completeness
left join {{ ref('mart_driver_season_standings') }} as standings
    on completeness.season = standings.season
where standings.season is null
group by completeness.season
