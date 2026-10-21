{#
  One row per constructor per season that has pit stop data (2011 onward).
  Stops longer than 60 seconds (red-flag stoppages, long repairs) are excluded
  from both the count and the median.
#}

with pit_stops as (
    select * from {{ ref('int_pit_stops__with_constructor') }}
    where is_representative_stop
),

constructors as (
    select * from {{ ref('stg_ergast__constructors') }}
)

select
    pit_stops.season,
    pit_stops.constructor_id,
    constructors.constructor_name,
    count(*)                                        as pit_stop_count,
    round(median(pit_stops.duration_ms) / 1000.0, 3) as median_pit_stop_seconds,
    round(avg(pit_stops.duration_ms) / 1000.0, 3)   as mean_pit_stop_seconds,
    round(min(pit_stops.duration_ms) / 1000.0, 3)   as fastest_pit_stop_seconds,
    count(distinct pit_stops.race_id)               as races_with_pit_data
from pit_stops
left join constructors
    on pit_stops.constructor_id = constructors.constructor_id
group by
    pit_stops.season,
    pit_stops.constructor_id,
    constructors.constructor_name
