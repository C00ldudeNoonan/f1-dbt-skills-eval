{#-
  "Are pit stops getting faster?" One row per season with pit stop data
  (2011 onward), using service stops only (<= 60 s).

  Raw medians are misleading because the calendar changes every year (2020's
  calendar was mostly unusual circuits). The comparable measures:
    - median_vs_circuit_s: the season's median stop relative to each
      circuit's all-time median (negative = faster than usual).
    - core_median_vs_circuit_s: the same, but only at circuits that held a
      race in at least 10 of the seasons, for a fixed set of venues.
    - best_crew_median_vs_circuit_s: the fastest constructor's median that
      season (min 20 stops). It tracks the best crews, which is what "pit stops
      are getting faster" usually means.
  All figures are pit-lane time; stationary time isn't in the data.
-#}
{%- set core_min_seasons = 10 -%}

with stops as (
    select * from {{ ref('int_pit_stops_enriched') }}
    where is_service_stop
),

team_seasons as (
    select season, constructor_id, median(delta_vs_circuit_ms) as team_median_delta_ms
    from stops
    group by season, constructor_id
    having count(*) >= 20
),

best_crew as (
    select season, min(team_median_delta_ms) as best_crew_median_delta_ms
    from team_seasons
    group by season
),

stints as (
    select race_id, driver_id, count(*) as stops
    from stops
    group by race_id, driver_id
),

season_stats as (
    select
        stops.season,
        count(*)                                                            as service_stops,
        count(distinct stops.race_id)                                       as races,
        count(distinct stops.circuit_id)                                    as circuits,
        median(stops.duration_ms) / 1000                                    as raw_median_s,
        median(stops.delta_vs_circuit_ms) / 1000                            as median_vs_circuit_s,
        percentile_cont(0.1) within group (order by stops.delta_vs_circuit_ms) / 1000 as p10_vs_circuit_s,
        median(iff(stops.circuit_seasons >= {{ core_min_seasons }}, stops.delta_vs_circuit_ms, null)) / 1000
                                                                            as core_median_vs_circuit_s,
        count_if(stops.circuit_seasons >= {{ core_min_seasons }})           as core_stops,
        min(stops.duration_ms) / 1000                                       as fastest_stop_s
    from stops
    group by stops.season
)

select
    season_stats.season,
    season_stats.service_stops,
    season_stats.races,
    season_stats.circuits,
    (select avg(stints.stops) from stints inner join stops using (race_id, driver_id) where stops.season = season_stats.season)::number(5, 2)
                                                                            as avg_stops_per_car_race,
    season_stats.raw_median_s::number(8, 3)                                 as raw_median_s,
    season_stats.median_vs_circuit_s::number(8, 3)                          as median_vs_circuit_s,
    season_stats.p10_vs_circuit_s::number(8, 3)                             as p10_vs_circuit_s,
    season_stats.core_median_vs_circuit_s::number(8, 3)                     as core_median_vs_circuit_s,
    season_stats.core_stops,
    (best_crew.best_crew_median_delta_ms / 1000)::number(8, 3)              as best_crew_median_vs_circuit_s,
    season_stats.fastest_stop_s::number(8, 3)                               as fastest_stop_s
from season_stats
left join best_crew
    on season_stats.season = best_crew.season
