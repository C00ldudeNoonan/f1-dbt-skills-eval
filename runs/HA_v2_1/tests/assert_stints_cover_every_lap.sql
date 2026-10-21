{#
    Every recorded lap of a driver in a race that has pit data belongs to exactly one
    stint, so the stint lap counts add up to the driver's lap count. Returns mismatches.
#}
with laps as (

    select race_id, driver_id, count(*) as laps
    from {{ ref('stg_f1__lap_times') }}
    where race_id in (select race_id from {{ ref('stg_f1__pit_stops') }})
    group by race_id, driver_id

),

stint_totals as (

    select race_id, driver_id, sum(stint_laps) as stint_laps
    from {{ ref('fct_stints') }}
    group by race_id, driver_id

)

select laps.race_id, laps.driver_id, laps.laps, stint_totals.stint_laps
from laps
left join stint_totals
    on laps.race_id = stint_totals.race_id
    and laps.driver_id = stint_totals.driver_id
where stint_totals.stint_laps is null
    or stint_totals.stint_laps <> laps.laps
