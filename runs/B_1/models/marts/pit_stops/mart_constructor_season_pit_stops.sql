{#
    Pit stop volume and typical stop time per constructor per season.
    Stop time is pit lane time (entry to exit), not stationary time.
#}

with pit_stops as (
    select * from {{ ref('int_pit_stops_enriched') }}
    where not is_red_flag_stoppage
),

constructors as (
    select * from {{ ref('stg_ergast__constructors') }}
),

aggregated as (
    select
        season,
        constructor_id,
        count(*)                                as pit_stop_count,
        median(duration_seconds)                as median_pit_stop_seconds,
        avg(duration_seconds)                   as mean_pit_stop_seconds,
        min(duration_seconds)                   as fastest_pit_stop_seconds
    from pit_stops
    group by season, constructor_id
)

select
    aggregated.season,
    aggregated.constructor_id,
    constructors.constructor_name,
    aggregated.pit_stop_count,
    round(aggregated.median_pit_stop_seconds, 3)    as median_pit_stop_seconds,
    round(aggregated.mean_pit_stop_seconds, 3)      as mean_pit_stop_seconds,
    aggregated.fastest_pit_stop_seconds
from aggregated
left join constructors
    on aggregated.constructor_id = constructors.constructor_id
