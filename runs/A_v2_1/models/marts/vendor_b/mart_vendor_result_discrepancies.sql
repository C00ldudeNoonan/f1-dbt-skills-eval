-- Where Vendor B disagrees with our primary feed (the system of record) on
-- 2018-2024 Grand Prix and sprint results: one row per entry per discrepancy.
--   points               both have the entry, points differ
--   position             both have the entry, classified finishing positions
--                        differ (classified in one feed only also counts; an
--                        entry unclassified in both is not a discrepancy)
--   missing_in_vendor_b  our entry has no Vendor B counterpart
--   missing_in_vendor_a  a Vendor B entry has no counterpart in our feed
-- Seasons compared: every season Vendor B delivers, from
-- var('vendor_b_first_season'), so new seasons are picked up automatically.
with covered_seasons as (

    select distinct season
    from {{ ref('stg_vendor_b__sessions') }}
    where season >= {{ var('vendor_b_first_season') }}

),

ours as (

    select race_id, session_type, driver_id, finish_position, position_text, points
    from {{ ref('fct_session_results') }}
    where season in (select season from covered_seasons)

),

theirs as (

    select
        sessions.race_id,
        sessions.session_type,
        drivers.driver_id,
        results.finish_position,
        results.position_text,
        results.points
    from {{ ref('stg_vendor_b__results') }} as results
    inner join {{ ref('dim_session_crosswalk') }} as sessions
        on results.session_key = sessions.session_key
    inner join {{ ref('dim_driver_crosswalk') }} as drivers
        on results.driver_key = drivers.driver_key
    where sessions.season in (select season from covered_seasons)
        -- Unmapped keys fail the crosswalk tests; keep them out of the comparison.
        and sessions.race_id is not null
        and drivers.driver_id is not null

),

paired as (

    select
        coalesce(ours.race_id, theirs.race_id) as race_id,
        coalesce(ours.session_type, theirs.session_type) as session_type,
        coalesce(ours.driver_id, theirs.driver_id) as driver_id,
        ours.driver_id is not null as in_vendor_a,
        theirs.driver_id is not null as in_vendor_b,
        ours.finish_position as a_position,
        theirs.finish_position as b_position,
        ours.position_text as a_position_text,
        theirs.position_text as b_position_text,
        ours.points as a_points,
        theirs.points as b_points
    from ours
    full outer join theirs
        on ours.race_id = theirs.race_id
        and ours.session_type = theirs.session_type
        and ours.driver_id = theirs.driver_id

),

discrepancies as (

    select race_id, session_type, driver_id, 'points' as discrepancy_type,
        a_points::varchar as vendor_a_value, b_points::varchar as vendor_b_value
    from paired
    where in_vendor_a and in_vendor_b and a_points != b_points

    union all

    select race_id, session_type, driver_id, 'position',
        coalesce(a_position::varchar, a_position_text), coalesce(b_position::varchar, b_position_text)
    from paired
    where in_vendor_a and in_vendor_b
        and a_position is distinct from b_position

    union all

    select race_id, session_type, driver_id, 'missing_in_vendor_b',
        coalesce(a_position::varchar, a_position_text), null
    from paired
    where in_vendor_a and not in_vendor_b

    union all

    select race_id, session_type, driver_id, 'missing_in_vendor_a',
        null, coalesce(b_position::varchar, b_position_text)
    from paired
    where in_vendor_b and not in_vendor_a

)

select * from discrepancies
