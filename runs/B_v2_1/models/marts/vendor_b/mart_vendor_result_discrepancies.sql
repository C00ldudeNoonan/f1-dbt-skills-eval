{#-
  Where Vendor B disagrees with our primary (Ergast, "vendor A") feed on Grand
  Prix and sprint results. One row per entry per discrepancy. Ergast stays the
  system of record; this model only reports.

  Scope: every season Vendor B covers (currently 2018-2024), both session types.
  Entries are keyed on (race_id, session_type, driver_id).
    - missing_in_vendor_b: we have the entry, Vendor B doesn't.
    - missing_in_vendor_a: Vendor B has the entry, we don't.
    - position: classified finishing positions differ, including classified in
      one feed and not the other. Unclassified in both is not a discrepancy.
    - points: points awarded differ.
  Values are text so every type fits one pair of columns.
-#}
with vendor_b_seasons as (
    select distinct season from {{ ref('dim_session_crosswalk') }}
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
    where results.season in (select season from vendor_b_seasons)
),

vendor_b as (
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
),

compared as (
    select
        coalesce(a.race_id, b.race_id)              as race_id,
        coalesce(a.session_type, b.session_type)    as session_type,
        coalesce(a.driver_id, b.driver_id)          as driver_id,
        a.race_id is not null                       as in_vendor_a,
        b.race_id is not null                       as in_vendor_b,
        a.finish_position                           as a_position,
        b.finish_position                           as b_position,
        a.position_text                             as a_position_text,
        b.position_text                             as b_position_text,
        a.points                                    as a_points,
        b.points                                    as b_points
    from vendor_a as a
    full outer join vendor_b as b
        on a.race_id = b.race_id
        and a.session_type = b.session_type
        and a.driver_id = b.driver_id
),

discrepancies as (
    select race_id, session_type, driver_id,
        'missing_in_vendor_b' as discrepancy_type,
        a_position_text as vendor_a_value, null as vendor_b_value
    from compared
    where in_vendor_a and not in_vendor_b

    union all

    select race_id, session_type, driver_id,
        'missing_in_vendor_a', null, b_position_text
    from compared
    where in_vendor_b and not in_vendor_a

    union all

    select race_id, session_type, driver_id,
        'position', a_position_text, b_position_text
    from compared
    where in_vendor_a and in_vendor_b
        and a_position is distinct from b_position

    union all

    select race_id, session_type, driver_id,
        'points', a_points::varchar, b_points::varchar
    from compared
    where in_vendor_a and in_vendor_b
        and a_points is distinct from b_points
)

select
    race_id,
    session_type,
    driver_id,
    discrepancy_type,
    vendor_a_value::varchar as vendor_a_value,
    vendor_b_value::varchar as vendor_b_value
from discrepancies
