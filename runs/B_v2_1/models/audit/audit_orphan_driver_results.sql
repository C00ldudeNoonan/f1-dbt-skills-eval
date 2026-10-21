{#-
  Grand Prix results whose driver_id has no record in `drivers` yet (late-
  arriving rookies and reserves). A view, so it is always current. Empty when
  every driver record has landed. Count rows for the number of orphan results.
-#}
select
    results.result_id,
    results.race_id,
    results.season,
    results.round,
    results.driver_id,
    results.constructor_id,
    results.position_order
from {{ ref('fct_results') }} as results
inner join {{ ref('int_driver_ids') }} as driver_ids
    on results.driver_id = driver_ids.driver_id
where not driver_ids.has_driver_record
