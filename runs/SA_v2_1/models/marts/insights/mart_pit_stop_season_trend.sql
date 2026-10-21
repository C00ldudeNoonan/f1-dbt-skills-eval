-- Are pit stops getting faster? Season by season, on a like-for-like basis.
-- Raw medians are misleading because the calendar changes every year and pit lanes differ by circuit by
-- many seconds. `circuit_adjusted_index` divides each stop by the median stop at that circuit over all
-- seasons (1.00 = a typical stop there), using only circuits with stops in at least 6 seasons, and takes the
-- season median. Stops over 60 s are excluded. Durations are pit lane time, not stationary time.
with stops as (

    select * from {{ ref('int_pit_stops_enriched') }} where is_included

),

circuit_baseline as (

    select circuit_id, median(duration_s) as baseline_s
    from stops
    group by circuit_id
    having count(distinct season) >= 6

),

indexed as (

    select
        stops.season,
        stops.race_id,
        stops.circuit_id,
        stops.duration_s,
        stops.duration_s / circuit_baseline.baseline_s as relative_duration
    from stops
    left join circuit_baseline on stops.circuit_id = circuit_baseline.circuit_id

)

select
    season,
    count(*) as stops,
    count(distinct race_id) as races,
    count(*) / count(distinct race_id) as stops_per_race,
    median(duration_s) as median_pit_lane_s,
    median(relative_duration) as circuit_adjusted_index,
    percentile_cont(0.10) within group (order by relative_duration) as fast_tail_index_p10,
    percentile_cont(0.90) within group (order by relative_duration) as slow_tail_index_p90,
    count_if(relative_duration is not null) as like_for_like_stops
from indexed
group by season
