{#
    For every driver in a race with pit data, the stints tile the driver's laps:
    each stint starts the lap after the previous one ends, the first starts on
    lap 1, and the stint lap counts add up to the driver's recorded laps.
#}
with ordered as (

    select
        race_id,
        driver_id,
        stint_number,
        start_lap,
        end_lap,
        stint_laps,
        lag(end_lap) over (partition by race_id, driver_id order by stint_number) as previous_end

    from {{ ref('fct_stints') }}

),

broken_chain as (

    select race_id, driver_id, stint_number
    from ordered
    where (stint_number = 1 and start_lap <> 1)
        or (stint_number > 1 and start_lap <> previous_end + 1)
        or end_lap < start_lap

),

lap_totals as (

    select
        race_id,
        driver_id,
        count(*) as recorded_laps
    from {{ ref('fct_lap_times') }}
    where race_id in (select race_id from {{ ref('stg_f1__pit_stops') }})
    group by race_id, driver_id

),

stint_totals as (

    select
        race_id,
        driver_id,
        sum(stint_laps) as stint_laps
    from {{ ref('fct_stints') }}
    group by race_id, driver_id

)

select race_id, driver_id, null as stint_number
from broken_chain

union all

select lap_totals.race_id, lap_totals.driver_id, null
from lap_totals
inner join stint_totals
    on lap_totals.race_id = stint_totals.race_id
    and lap_totals.driver_id = stint_totals.driver_id
where lap_totals.recorded_laps <> stint_totals.stint_laps
