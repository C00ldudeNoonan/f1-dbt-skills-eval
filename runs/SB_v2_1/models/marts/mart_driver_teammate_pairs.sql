-- Grain: one row per driver and teammate (all seasons and constructors they shared). The transparent building
-- block behind mart_driver_overperformance: "who did this driver beat, by how much, over how many weekends".
-- Percent of lap time; NEGATIVE = the driver was faster than that teammate.
select
    driver_id,
    teammate_id,
    count(distinct season)::integer as seasons_together,
    min(season)::integer as first_season,
    max(season)::integer as last_season,
    count(qual_delta_pct)::integer as qualifying_comparisons,
    avg(qual_delta_pct)::number(8, 4) as mean_qual_delta_pct,
    count(race_pace_delta_pct)::integer as race_pace_comparisons,
    avg(race_pace_delta_pct)::number(8, 4) as mean_race_pace_delta_pct
from {{ ref('int_teammate_pace_deltas') }}
group by driver_id, teammate_id
