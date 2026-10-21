-- Each teammate comparison appears in both orderings with the same two
-- times swapped, so (driver, teammate) and (teammate, driver) always agree.
select driver_side.race_id, driver_side.driver_id, driver_side.teammate_id
from {{ ref('int_f1__teammate_qualifying_comparisons') }} as driver_side
left join {{ ref('int_f1__teammate_qualifying_comparisons') }} as teammate_side
    on driver_side.race_id = teammate_side.race_id
    and driver_side.driver_id = teammate_side.teammate_id
    and driver_side.teammate_id = teammate_side.driver_id
where teammate_side.race_id is null
    or driver_side.driver_time_ms <> teammate_side.teammate_time_ms
    or driver_side.compared_session <> teammate_side.compared_session
