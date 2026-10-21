-- fct_lap_times must hold exactly the staged laps with the same times. Catches
-- incremental drift: missed races, or corrections outside the reload window
-- (fix with `dbt build --full-refresh -s fct_lap_times+`).
with fact as (

    select race_id, driver_id, lap, lap_time_ms from {{ ref('fct_lap_times') }}

),

staged as (

    select race_id, driver_id, lap, lap_time_ms from {{ ref('stg_ergast__lap_times') }}

)

select
    coalesce(fact.race_id, staged.race_id) as race_id,
    coalesce(fact.driver_id, staged.driver_id) as driver_id,
    coalesce(fact.lap, staged.lap) as lap,
    fact.lap_time_ms as fact_lap_time_ms,
    staged.lap_time_ms as staged_lap_time_ms
from fact
full outer join staged
    on fact.race_id = staged.race_id
    and fact.driver_id = staged.driver_id
    and fact.lap = staged.lap
where fact.lap_time_ms is distinct from staged.lap_time_ms
