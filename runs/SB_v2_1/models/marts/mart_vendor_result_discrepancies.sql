-- Grain: one row per entry (race, session type, driver) per discrepancy between our primary feed (vendor A,
-- the system of record) and Vendor B, over the seasons Vendor B covers.
--   points              both feeds have the entry but award different points
--   position            classified finishing positions differ (an entry unclassified in both is not a discrepancy)
--   missing_in_vendor_b entry exists in our feed only
--   missing_in_vendor_a entry exists in Vendor B only
-- For the two 'missing' types the side that has the entry shows its points; the other side is null.
with window_ as (
    select * from {{ ref('int_vendor_b_window') }}
),

vendor_a as (
    select race_id, session_type, driver_id, finish_position, points
    from {{ ref('fct_session_results') }}
    cross join window_
    where season between window_.first_season and window_.last_season
),

vendor_b as (
    select
        sessions.race_id,
        sessions.session_type,
        drivers.driver_id,
        results.position as finish_position,
        results.points
    from {{ ref('stg_f1__vb_results') }} as results
    inner join {{ ref('dim_session_crosswalk') }} as sessions on sessions.session_key = results.session_key
    inner join {{ ref('dim_driver_crosswalk') }} as drivers on drivers.driver_key = results.driver_key
),

joined as (
    select
        coalesce(a.race_id, b.race_id) as race_id,
        coalesce(a.session_type, b.session_type) as session_type,
        coalesce(a.driver_id, b.driver_id) as driver_id,
        a.driver_id is not null as in_a,
        b.driver_id is not null as in_b,
        a.finish_position as a_position,
        b.finish_position as b_position,
        a.points as a_points,
        b.points as b_points
    from vendor_a as a
    full outer join vendor_b as b
        on a.race_id = b.race_id
        and a.session_type = b.session_type
        and a.driver_id = b.driver_id
),

discrepancies as (
    select race_id, session_type, driver_id, 'points' as discrepancy_type, a_points as vendor_a_value, b_points as vendor_b_value
    from joined where in_a and in_b and a_points is distinct from b_points

    union all

    select race_id, session_type, driver_id, 'position', a_position, b_position
    from joined where in_a and in_b and a_position is distinct from b_position

    union all

    select race_id, session_type, driver_id, 'missing_in_vendor_b', a_points, null
    from joined where in_a and not in_b

    union all

    select race_id, session_type, driver_id, 'missing_in_vendor_a', null, b_points
    from joined where in_b and not in_a
)

select
    race_id::integer as race_id,
    session_type,
    driver_id::integer as driver_id,
    discrepancy_type,
    vendor_a_value::number(12, 2) as vendor_a_value,
    vendor_b_value::number(12, 2) as vendor_b_value
from discrepancies
