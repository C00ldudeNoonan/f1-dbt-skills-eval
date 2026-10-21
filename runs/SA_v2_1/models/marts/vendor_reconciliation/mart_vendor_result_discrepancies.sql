-- Where Vendor B and the primary feed (Vendor A, the system of record) disagree on Grand Prix and
-- sprint results, for the seasons Vendor B covers. One row per entry per discrepancy:
--   points               both have the entry, points differ (values are the points)
--   position             both have the entry, classified finishing positions differ; an entry unclassified
--                        in both feeds is not a discrepancy (value = position, or the vendor's DNF/DSQ text)
--   missing_in_vendor_b  only the primary feed has the entry (value = its finishing position)
--   missing_in_vendor_a  only Vendor B has the entry (value = its position text)
-- Sessions Vendor B lacks entirely (within its seasons) therefore show every entry as missing_in_vendor_b.
with vendor_seasons as (

    select distinct season from {{ ref('dim_session_crosswalk') }}

),

vendor_a as (

    select race_id, session_type, driver_id, finish_position, points
    from {{ ref('fct_session_results') }}
    where season in (select season from vendor_seasons)

),

vendor_b as (

    select
        sessions.race_id,
        sessions.session_type,
        drivers.driver_id,
        results.finish_position,
        results.position_raw,
        results.points
    from {{ ref('stg_vendor_b__results') }} as results
    inner join {{ ref('dim_session_crosswalk') }} as sessions on results.session_key = sessions.session_key
    inner join {{ ref('dim_driver_crosswalk') }} as drivers on results.driver_key = drivers.driver_key
    where sessions.race_id is not null and drivers.driver_id is not null

),

joined as (

    select
        coalesce(a.race_id, b.race_id) as race_id,
        coalesce(a.session_type, b.session_type) as session_type,
        coalesce(a.driver_id, b.driver_id) as driver_id,
        a.driver_id is not null as in_a,
        b.driver_id is not null as in_b,
        a.finish_position as a_position,
        a.points as a_points,
        b.finish_position as b_position,
        b.position_raw as b_position_raw,
        b.points as b_points
    from vendor_a as a
    full outer join vendor_b as b
        on a.race_id = b.race_id
        and a.session_type = b.session_type
        and a.driver_id = b.driver_id

)

select race_id, session_type, driver_id, 'missing_in_vendor_b' as discrepancy_type,
    to_varchar(a_position) as vendor_a_value, null as vendor_b_value
from joined where in_a and not in_b

union all

select race_id, session_type, driver_id, 'missing_in_vendor_a',
    null, b_position_raw
from joined where in_b and not in_a

union all

select race_id, session_type, driver_id, 'points',
    to_varchar(a_points), to_varchar(b_points)
from joined where in_a and in_b and a_points <> b_points

union all

select race_id, session_type, driver_id, 'position',
    to_varchar(a_position), b_position_raw
from joined where in_a and in_b and a_position is distinct from b_position
