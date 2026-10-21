{#
    One row per entry per discrepancy, where our primary feed (fct_session_results) and Vendor B
    disagree on 2018 to 2024 Grand Prix and sprint results. Our feed is the system of record.

    discrepancy_type:
      missing_in_vendor_b  an entry we have that Vendor B does not.
      missing_in_vendor_a  a Vendor B entry we do not have.
      points               both have it, and the points differ.
      position             both have it, and the classified position differs. Unclassified in
                           both is not a discrepancy (null-safe comparison).

    vendor_a_value and vendor_b_value are points for points and missing discrepancies, and
    classified position for position discrepancies. The side that is missing is null.
#}
with vendor_b as (

    select
        sessions.race_id,
        sessions.session_type,
        drivers.driver_id,
        results.points as vendor_b_points,
        results.position_number as vendor_b_position
    from {{ ref('stg_vb__results') }} as results
    inner join {{ ref('dim_session_crosswalk') }} as sessions
        on results.session_key = sessions.session_key
    inner join {{ ref('dim_driver_crosswalk') }} as drivers
        on results.driver_key = drivers.driver_key

),

primary_feed as (

    select
        race_id,
        session_type,
        driver_id,
        points as vendor_a_points,
        finish_position as vendor_a_position
    from {{ ref('fct_session_results') }}
    where season between 2018 and 2024

),

joined as (

    select
        coalesce(primary_feed.race_id, vendor_b.race_id) as race_id,
        coalesce(primary_feed.session_type, vendor_b.session_type) as session_type,
        coalesce(primary_feed.driver_id, vendor_b.driver_id) as driver_id,
        primary_feed.vendor_a_points,
        primary_feed.vendor_a_position,
        vendor_b.vendor_b_points,
        vendor_b.vendor_b_position,
        primary_feed.race_id is not null as in_vendor_a,
        vendor_b.race_id is not null as in_vendor_b
    from primary_feed
    full outer join vendor_b
        on primary_feed.race_id = vendor_b.race_id
        and primary_feed.session_type = vendor_b.session_type
        and primary_feed.driver_id = vendor_b.driver_id

)

select
    race_id,
    session_type,
    driver_id,
    'missing_in_vendor_b' as discrepancy_type,
    vendor_a_points::number(8, 2) as vendor_a_value,
    cast(null as number(8, 2)) as vendor_b_value
from joined
where in_vendor_a and not in_vendor_b

union all

select
    race_id,
    session_type,
    driver_id,
    'missing_in_vendor_a' as discrepancy_type,
    cast(null as number(8, 2)) as vendor_a_value,
    vendor_b_points::number(8, 2) as vendor_b_value
from joined
where in_vendor_b and not in_vendor_a

union all

select
    race_id,
    session_type,
    driver_id,
    'points' as discrepancy_type,
    vendor_a_points::number(8, 2) as vendor_a_value,
    vendor_b_points::number(8, 2) as vendor_b_value
from joined
where in_vendor_a and in_vendor_b
    and vendor_a_points is distinct from vendor_b_points

union all

select
    race_id,
    session_type,
    driver_id,
    'position' as discrepancy_type,
    vendor_a_position::number(8, 2) as vendor_a_value,
    vendor_b_position::number(8, 2) as vendor_b_value
from joined
where in_vendor_a and in_vendor_b
    and vendor_a_position is distinct from vendor_b_position
