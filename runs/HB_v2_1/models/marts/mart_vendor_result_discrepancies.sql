{#
    Where the two feeds disagree on Grand Prix and sprint results, for the seasons Vendor B
    covers. Our feed (fct_session_results) is the system of record. One row per entry per
    discrepancy:

      missing_in_vendor_b  an entry we have that Vendor B does not
      missing_in_vendor_a  an entry Vendor B has that we do not
      points               both have the entry and the points differ
      position             both have the entry and the classified position differs.
                           An entry unclassified in both feeds is not a discrepancy.

    The season range is taken from Vendor B's own data, so it extends as the feed does.
#}
with coverage as (

    select
        min(season) as first_season,
        max(season) as last_season
    from {{ ref('stg_vendor_b__sessions') }}

),

ours as (

    select
        results.race_id,
        results.session_type,
        results.driver_id,
        results.finish_position,
        results.points

    from {{ ref('fct_session_results') }} as results
    cross join coverage
    where results.season between coverage.first_season and coverage.last_season

),

vendor_b as (

    select
        sessions.race_id,
        sessions.session_type,
        drivers.driver_id,
        results.position,
        results.position_text,
        results.points

    from {{ ref('stg_vendor_b__results') }} as results
    inner join {{ ref('dim_session_crosswalk') }} as sessions
        on results.session_key = sessions.session_key
    inner join {{ ref('dim_driver_crosswalk') }} as drivers
        on results.driver_key = drivers.driver_key

),

joined as (

    select
        coalesce(ours.race_id, vendor_b.race_id) as race_id,
        coalesce(ours.session_type, vendor_b.session_type) as session_type,
        coalesce(ours.driver_id, vendor_b.driver_id) as driver_id,
        ours.race_id is not null as in_ours,
        vendor_b.race_id is not null as in_vendor_b,
        ours.finish_position as our_position,
        vendor_b.position as vb_position,
        vendor_b.position_text as vb_position_text,
        ours.points as our_points,
        vendor_b.points as vb_points

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
    our_position::varchar as vendor_a_value,
    null::varchar as vendor_b_value
from joined
where in_ours and not in_vendor_b

union all

select
    race_id,
    session_type,
    driver_id,
    'missing_in_vendor_a',
    null::varchar,
    coalesce(vb_position::varchar, vb_position_text)
from joined
where in_vendor_b and not in_ours

union all

select
    race_id,
    session_type,
    driver_id,
    'points',
    our_points::varchar,
    vb_points::varchar
from joined
where in_ours and in_vendor_b
    and abs(our_points - vb_points) > 0.001

union all

select
    race_id,
    session_type,
    driver_id,
    'position',
    coalesce(our_position::varchar, 'unclassified'),
    coalesce(vb_position::varchar, vb_position_text)
from joined
where in_ours and in_vendor_b
    and (
        (our_position is null) <> (vb_position is null)
        or our_position <> vb_position
    )
