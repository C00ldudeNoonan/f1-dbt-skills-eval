{#
    Stints partition each driver's laps, so for every race with pit stop data the stint lap
    counts must add up to the race's total lap rows. A gap or an overlap in stint boundaries fails here.
#}
with expected as (

    select
        race_id,
        count(*) as lap_rows
    from {{ ref('stg_f1__lap_times') }}
    where race_id in (select race_id from {{ ref('stg_f1__pit_stops') }})
    group by race_id

),

actual as (

    select
        race_id,
        sum(stint_laps) as stint_lap_rows
    from {{ ref('fct_stints') }}
    group by race_id

)

select
    expected.race_id,
    expected.lap_rows,
    actual.stint_lap_rows
from expected
left join actual
    on expected.race_id = actual.race_id
where actual.stint_lap_rows is null
    or actual.stint_lap_rows <> expected.lap_rows
