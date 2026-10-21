-- Every disagreement between our primary feed (vendor A, the system of
-- record) and Vendor B on Grand Prix and sprint results. One row per entry
-- per discrepancy type:
--   missing_in_vendor_b  we have the entry, Vendor B doesn't
--   missing_in_vendor_a  Vendor B has the entry, we don't
--   points               both have the entry, points differ
--   position             both have the entry, classified finishing positions
--                        differ. Classified in one feed only also counts, but
--                        unclassified in both doesn't.
-- Coverage follows the seasons Vendor B delivers, so new seasons are compared
-- automatically. Values are text so one column can hold points, positions and
-- classification codes.

with sessions as (
    select * from {{ ref('dim_session_crosswalk') }}
    where race_id is not null
),

drivers as (
    select * from {{ ref('dim_driver_crosswalk') }}
    where driver_id is not null
),

vendor_b_coverage as (
    select
        min(season) as first_season,
        max(season) as last_season
    from sessions
),

vendor_a as (
    select
        results.race_id,
        results.session_type,
        results.driver_id,
        results.finish_position,
        results.position_text,
        results.points
    from {{ ref('fct_session_results') }} as results
    cross join vendor_b_coverage
    where results.season between vendor_b_coverage.first_season and vendor_b_coverage.last_season
),

vendor_b as (
    select
        sessions.race_id,
        sessions.session_type,
        drivers.driver_id,
        vendor_results.finish_position,
        vendor_results.position_text,
        vendor_results.points
    from {{ ref('stg_vendor_b__results') }} as vendor_results
    inner join sessions
        on vendor_results.session_key = sessions.session_key
    inner join drivers
        on vendor_results.driver_key = drivers.driver_key
),

compared as (
    select
        coalesce(vendor_a.race_id, vendor_b.race_id) as race_id,
        coalesce(vendor_a.session_type, vendor_b.session_type) as session_type,
        coalesce(vendor_a.driver_id, vendor_b.driver_id) as driver_id,
        vendor_a.race_id is not null as in_vendor_a,
        vendor_b.race_id is not null as in_vendor_b,
        vendor_a.finish_position as a_finish_position,
        vendor_b.finish_position as b_finish_position,
        coalesce(vendor_a.finish_position::varchar, vendor_a.position_text) as a_position_value,
        coalesce(vendor_b.finish_position::varchar, vendor_b.position_text) as b_position_value,
        vendor_a.points as a_points,
        vendor_b.points as b_points
    from vendor_a
    full outer join vendor_b
        on vendor_a.race_id = vendor_b.race_id
        and vendor_a.session_type = vendor_b.session_type
        and vendor_a.driver_id = vendor_b.driver_id
),

discrepancies as (
    select race_id, session_type, driver_id, 'missing_in_vendor_b' as discrepancy_type,
        a_position_value as vendor_a_value, null::varchar as vendor_b_value
    from compared
    where in_vendor_a and not in_vendor_b

    union all

    select race_id, session_type, driver_id, 'missing_in_vendor_a',
        null::varchar, b_position_value
    from compared
    where in_vendor_b and not in_vendor_a

    union all

    select race_id, session_type, driver_id, 'points',
        a_points::varchar, b_points::varchar
    from compared
    where in_vendor_a and in_vendor_b
        and a_points is distinct from b_points

    union all

    select race_id, session_type, driver_id, 'position',
        a_position_value, b_position_value
    from compared
    where in_vendor_a and in_vendor_b
        and (a_finish_position is not null or b_finish_position is not null)
        and a_finish_position is distinct from b_finish_position
)

select * from discrepancies
