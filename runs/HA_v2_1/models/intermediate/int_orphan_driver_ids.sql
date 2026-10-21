{#
    Driver ids referenced by race or lap data that have no record in the drivers feed yet
    (for example a rookie's result arriving before their driver record). One row per
    orphan driver_id, with the number of rows referencing it per source.
    Empty once the driver record arrives.
#}
with referenced as (

    select driver_id, 'results' as source_name from {{ ref('stg_f1__results') }}
    union all
    select driver_id, 'sprint_results' from {{ ref('stg_f1__sprint_results') }}
    union all
    select driver_id, 'qualifying' from {{ ref('stg_f1__qualifying') }}
    union all
    select driver_id, 'driver_standings' from {{ ref('stg_f1__driver_standings') }}
    union all
    select driver_id, 'pit_stops' from {{ ref('stg_f1__pit_stops') }}
    union all
    select driver_id, 'lap_times' from {{ ref('stg_f1__lap_times') }}

),

orphans as (

    select referenced.driver_id, referenced.source_name
    from referenced
    left join {{ ref('stg_f1__drivers') }} as drivers
        on referenced.driver_id = drivers.driver_id
    where drivers.driver_id is null

)

select
    driver_id,
    count_if(source_name = 'results') as result_rows,
    count_if(source_name = 'sprint_results') as sprint_result_rows,
    count_if(source_name = 'qualifying') as qualifying_rows,
    count_if(source_name = 'driver_standings') as standings_rows,
    count_if(source_name = 'pit_stops') as pit_stop_rows,
    count_if(source_name = 'lap_times') as lap_rows
from orphans
group by driver_id
