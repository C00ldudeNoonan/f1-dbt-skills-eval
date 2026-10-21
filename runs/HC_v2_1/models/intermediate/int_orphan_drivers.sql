{#
    Driver IDs that appear in race or timing feeds but have no record in the drivers table yet.
    The results feed can deliver a result before the driver's record arrives (rookies and reserve drivers).
    Each row is one such driver with the number of rows they have in each feed.

    dim_drivers builds a placeholder row for each of these IDs, and the placeholder disappears
    automatically once the driver record arrives. Use this model to see how many results are waiting.
#}
with known_drivers as (

    select driver_id from {{ ref('stg_f1__drivers') }}

),

results_by_driver as (

    select driver_id, count(*) as result_rows
    from {{ ref('stg_f1__results') }}
    group by driver_id

),

qualifying_by_driver as (

    select driver_id, count(*) as qualifying_rows
    from {{ ref('stg_f1__qualifying') }}
    group by driver_id

),

standings_by_driver as (

    select driver_id, count(*) as standings_rows
    from {{ ref('stg_f1__driver_standings') }}
    group by driver_id

),

all_driver_ids as (

    select driver_id from results_by_driver
    union
    select driver_id from qualifying_by_driver
    union
    select driver_id from standings_by_driver

)

select
    all_driver_ids.driver_id,
    coalesce(results_by_driver.result_rows, 0) as orphan_result_count,
    coalesce(qualifying_by_driver.qualifying_rows, 0) as orphan_qualifying_count,
    coalesce(standings_by_driver.standings_rows, 0) as orphan_standings_count
from all_driver_ids
left join known_drivers
    on all_driver_ids.driver_id = known_drivers.driver_id
left join results_by_driver
    on all_driver_ids.driver_id = results_by_driver.driver_id
left join qualifying_by_driver
    on all_driver_ids.driver_id = qualifying_by_driver.driver_id
left join standings_by_driver
    on all_driver_ids.driver_id = standings_by_driver.driver_id
where known_drivers.driver_id is null
