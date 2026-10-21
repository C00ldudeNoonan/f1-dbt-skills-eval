{#
    Pit stop time by season, from 2011. Two views:
      - raw: the median stop time as recorded. Mixes circuit effects with crew performance.
      - adjusted: stop time relative to each circuit's own median, averaged over stable circuits only. This is the
        fair view for "are stops getting faster". Negative means faster than that circuit's typical stop.
#}
with stops as (

    select * from {{ ref('int_pit_stops_circuit_adjusted') }}

)

select
    season,
    count(*) as stops,
    count(distinct race_id) as races,
    round(median(stop_seconds), 3) as median_stop_seconds,
    count_if(circuit_is_stable) as stable_circuit_stops,
    round(avg(iff(circuit_is_stable, seconds_vs_circuit, null)), 3) as mean_seconds_vs_circuit,
    round(median(iff(circuit_is_stable, seconds_vs_circuit, null)), 3) as median_seconds_vs_circuit
from stops
group by season
