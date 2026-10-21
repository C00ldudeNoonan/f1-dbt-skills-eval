-- Where Vendor B disagrees with our primary feed (the system of record) on Grand Prix and
-- sprint results, for the seasons Vendor B covers. One row per entry per discrepancy:
--   points               both feeds have the entry but score it differently
--   position             both have the entry but classified finishing positions differ (an
--                        entry unclassified in both is not a discrepancy)
--   missing_in_vendor_b  we have the entry, Vendor B does not
--   missing_in_vendor_a  Vendor B has the entry, we do not
-- For missing_* rows the value on the side that has the entry is its finishing position
-- ('NC' when unclassified) and the other side is null.
with vendor_seasons as (

    select min(season) as first_season, max(season) as last_season
    from {{ ref('stg_f1__vb_sessions') }}

),

vendor_a as (

    select
        results.race_id,
        results.session_type,
        results.driver_id,
        results.finish_position,
        results.points
    from {{ ref('fct_session_results') }} as results
    cross join vendor_seasons
    where results.season between vendor_seasons.first_season and vendor_seasons.last_season

),

vendor_b as (

    select
        sessions.race_id,
        sessions.session_type,
        drivers.driver_id,
        results.finish_position,
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
        a.race_id is not null as in_a,
        b.race_id is not null as in_b,
        a.finish_position as a_position,
        b.finish_position as b_position,
        a.points as a_points,
        b.points as b_points
    from vendor_a as a
    full outer join vendor_b as b
        on a.race_id = b.race_id
        and a.session_type = b.session_type
        and a.driver_id = b.driver_id

)

select
    race_id,
    session_type,
    driver_id,
    'points' as discrepancy_type,
    a_points::varchar as vendor_a_value,
    b_points::varchar as vendor_b_value
from joined
where in_a and in_b and a_points <> b_points

union all

select
    race_id,
    session_type,
    driver_id,
    'position',
    a_position::varchar,
    b_position::varchar
from joined
where in_a and in_b and a_position is distinct from b_position

union all

select
    race_id,
    session_type,
    driver_id,
    'missing_in_vendor_b',
    coalesce(a_position::varchar, 'NC'),
    null
from joined
where in_a and not in_b

union all

select
    race_id,
    session_type,
    driver_id,
    'missing_in_vendor_a',
    null,
    coalesce(b_position::varchar, 'NC')
from joined
where in_b and not in_a
