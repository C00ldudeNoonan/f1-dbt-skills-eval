{#
    Every pit stop that counts toward the constructor metrics is at or under the red-flag
    threshold, and the metric totals match a direct count of those stops. The count is taken
    from staging, not fct_results, so a fan-out in fct_results cannot hide here.
#}
with counted as (

    select count(*) as expected_stops
    from {{ ref('stg_f1__pit_stops') }} as pit_stops
    inner join {{ ref('stg_f1__results') }} as results
        on pit_stops.race_id = results.race_id
        and pit_stops.driver_id = results.driver_id
    where pit_stops.pit_stop_ms <= {{ var('red_flag_pit_stop_ms') }}

),

metric as (

    select sum(pit_stop_count) as reported_stops
    from {{ ref('mart_constructor_season_pit_stops') }}

)

select *
from counted
cross join metric
where expected_stops <> reported_stops
