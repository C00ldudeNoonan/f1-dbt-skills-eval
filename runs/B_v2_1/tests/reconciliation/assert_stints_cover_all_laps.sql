-- For races with pit stop data, every recorded lap belongs to exactly one stint.
with lap_counts as (
    select laps.race_id, laps.driver_id, count(*) as laps
    from {{ ref('fct_lap_times') }} as laps
    where laps.race_id in (select race_id from {{ ref('stg_ergast__pit_stops') }})
    group by 1, 2
),

stint_counts as (
    select race_id, driver_id, sum(stint_laps) as laps
    from {{ ref('fct_stints') }}
    group by 1, 2
)

select
    coalesce(lap_counts.race_id, stint_counts.race_id)     as race_id,
    coalesce(lap_counts.driver_id, stint_counts.driver_id) as driver_id,
    lap_counts.laps     as recorded_laps,
    stint_counts.laps   as stint_laps
from lap_counts
full outer join stint_counts
    on lap_counts.race_id = stint_counts.race_id
    and lap_counts.driver_id = stint_counts.driver_id
where lap_counts.laps is distinct from stint_counts.laps
