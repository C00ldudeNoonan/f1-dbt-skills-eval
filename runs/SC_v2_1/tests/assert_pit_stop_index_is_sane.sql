-- The index starts at 100, and no season-on-season change is implausibly large (a sign of a unit
-- change or a broken circuit join rather than a real change in pit lane time).
select season, chained_index, change_vs_previous_season_pct
from {{ ref('mart_pit_stop_trend_by_season') }}
where (season = (select min(season) from {{ ref('mart_pit_stop_trend_by_season') }}) and abs(chained_index - 100) > 1e-6)
    or abs(coalesce(change_vs_previous_season_pct, 0)) > 15
    or raw_median_seconds not between 10 and 40
