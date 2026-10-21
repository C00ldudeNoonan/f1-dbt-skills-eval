{#
    One row per entry per discrepancy wherever our feed and Vendor B disagree on 2018 to 2024 Grand Prix and sprint
    results. Our feed is the system of record; Vendor B is the cross-check.

    Entries are compared on (race_id, session_type, driver_id). Discrepancy types:
      - points: both feeds have the entry, points differ.
      - position: both feeds have the entry, the classified finishing position differs. A position is classified only
        when it is a number. Entries unclassified in both feeds (DNF, DSQ, retirements) are not a position discrepancy.
        One classified and one unclassified is a discrepancy.
      - missing_in_vendor_b: our feed has the entry, Vendor B does not. vendor_a_value is our points.
      - missing_in_vendor_a: Vendor B has the entry, our feed does not. vendor_b_value is its points.
    Values are points for points and missing rows, and finishing positions for position rows (null when unclassified).
#}
with ours as (

    select
        race_id,
        session_type,
        driver_id,
        finish_position,
        points
    from {{ ref('fct_session_results') }}
    where season between 2018 and 2024

),

vendor_b as (

    select
        sessions.race_id,
        sessions.session_type,
        drivers.driver_id,
        results.position as finish_position,
        results.points
    from {{ ref('stg_f1__vb_results') }} as results
    inner join {{ ref('dim_session_crosswalk') }} as sessions
        on results.session_key = sessions.session_key
    inner join {{ ref('dim_driver_crosswalk') }} as drivers
        on results.driver_key = drivers.driver_key

),

matched as (

    select
        coalesce(ours.race_id, vendor_b.race_id) as race_id,
        coalesce(ours.session_type, vendor_b.session_type) as session_type,
        coalesce(ours.driver_id, vendor_b.driver_id) as driver_id,
        ours.driver_id is not null as in_ours,
        vendor_b.driver_id is not null as in_vendor_b,
        ours.finish_position as our_position,
        vendor_b.finish_position as vendor_b_position,
        ours.points as our_points,
        vendor_b.points as vendor_b_points
    from ours
    full outer join vendor_b
        on ours.race_id = vendor_b.race_id
        and ours.session_type = vendor_b.session_type
        and ours.driver_id = vendor_b.driver_id

)

select
    race_id,
    session_type,
    driver_id,
    'missing_in_vendor_b' as discrepancy_type,
    our_points::numeric(6, 2) as vendor_a_value,
    null::numeric(6, 2) as vendor_b_value
from matched
where in_ours and not in_vendor_b

union all

select
    race_id,
    session_type,
    driver_id,
    'missing_in_vendor_a' as discrepancy_type,
    null::numeric(6, 2) as vendor_a_value,
    vendor_b_points::numeric(6, 2) as vendor_b_value
from matched
where in_vendor_b and not in_ours

union all

select
    race_id,
    session_type,
    driver_id,
    'points' as discrepancy_type,
    our_points::numeric(6, 2) as vendor_a_value,
    vendor_b_points::numeric(6, 2) as vendor_b_value
from matched
where in_ours and in_vendor_b
    and our_points is distinct from vendor_b_points

union all

select
    race_id,
    session_type,
    driver_id,
    'position' as discrepancy_type,
    our_position::numeric(6, 2) as vendor_a_value,
    vendor_b_position::numeric(6, 2) as vendor_b_value
from matched
where in_ours and in_vendor_b
    and (our_position is not null or vendor_b_position is not null)
    and our_position is distinct from vendor_b_position
