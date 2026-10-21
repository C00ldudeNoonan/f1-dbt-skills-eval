-- Grain: one row per season with pit stop data (2011 onward). Are pit stops getting faster?
--   raw_median_seconds    median pit lane time of all routine stops. MISLEADING on its own: the calendar changes
--                         every year, so it mostly measures which circuits were visited.
--   circuit_adjusted_index  stop-weighted mean of each circuit's `relative_to_circuit`, using circuits seen in at
--                         least 3 seasons. 1.000 = typical for those circuits; compare seasons with this column.
--   change_vs_first_season_pct  adjusted index relative to the first season (negative = faster)
-- Limitation: times are pit lane entry to exit, not the 2-3 s stationary stop, so crew improvements are largely
-- invisible in this data.
with circuit_seasons as (
    select * from {{ ref('mart_pit_stop_circuit_season') }}
),

adjusted as (
    select
        season,
        sum(relative_to_circuit * stops) / sum(stops) as circuit_adjusted_index,
        count(*) as circuits_in_index
    from circuit_seasons
    where seasons_at_circuit >= 3
    group by season
),

raw as (
    select season, count(*) as stops, count(distinct race_id) as races, median(duration_seconds) as raw_median_seconds
    from {{ ref('int_pit_stops_routine') }}
    group by season
),

combined as (
    select
        raw.season,
        raw.races,
        raw.stops,
        raw.raw_median_seconds,
        adjusted.circuit_adjusted_index,
        adjusted.circuits_in_index
    from raw
    left join adjusted on adjusted.season = raw.season
)

select
    season::integer as season,
    races::integer as races,
    stops::integer as stops,
    raw_median_seconds::number(8, 3) as raw_median_seconds,
    circuit_adjusted_index::number(8, 4) as circuit_adjusted_index,
    circuits_in_index::integer as circuits_in_index,
    (100.0 * (circuit_adjusted_index / first_value(circuit_adjusted_index) over (order by season) - 1))::number(8, 3) as change_vs_first_season_pct,
    (100.0 * (circuit_adjusted_index / lag(circuit_adjusted_index) over (order by season) - 1))::number(8, 3) as change_vs_previous_season_pct
from combined
