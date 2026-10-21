-- Red-flag stoppages (over 60 seconds) must not inflate the median or count.
select
    season,
    constructor_id,
    median_pit_stop_seconds
from {{ ref('mart_constructor_season_pit_stops') }}
where median_pit_stop_seconds > 60
    or median_pit_stop_seconds <= 0
    or pit_stop_count < 1
