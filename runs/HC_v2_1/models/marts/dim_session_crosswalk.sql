{#
    One row per Vendor B session, with the matching race_id and session type ('race' or 'sprint').

    How a session is matched (automatic):
      1. Candidates are our sessions in the same season and of the same type, whose date is within three days of the
         Vendor B session date. Races use race_date. Sprints use sprint_date.
      2. Each candidate is scored by how many drivers the two sessions share. Drivers are compared through
         dim_driver_crosswalk, so the score only counts drivers that matched.
      3. The candidate with the most shared drivers wins (closest date breaks a tie). The match is accepted only when at
         least 80% of the Vendor B entries are found in our session.
    A session that cannot be matched has a null race_id, and the build fails on the not_null test.
#}
with vendor_b_sessions as (

    select
        session_key,
        session_type,
        season,
        session_date
    from {{ ref('stg_f1__vb_sessions') }}

),

vendor_b_entries as (

    select
        results.session_key,
        crosswalk.driver_id
    from {{ ref('stg_f1__vb_results') }} as results
    inner join {{ ref('dim_driver_crosswalk') }} as crosswalk
        on results.driver_key = crosswalk.driver_key
    where crosswalk.driver_id is not null

),

our_sessions as (

    select distinct
        fct.race_id,
        fct.session_type,
        fct.season,
        case when fct.session_type = 'race' then fct.race_date else races.sprint_date end as session_date
    from {{ ref('fct_session_results') }} as fct
    inner join {{ ref('stg_f1__races') }} as races
        on fct.race_id = races.race_id

),

our_entries as (

    select distinct
        race_id,
        session_type,
        driver_id
    from {{ ref('fct_session_results') }}

),

our_session_sizes as (

    select
        race_id,
        session_type,
        count(*) as our_entries
    from our_entries
    group by race_id, session_type

),

vendor_b_session_sizes as (

    select
        session_key,
        count(distinct driver_id) as vendor_b_entries
    from vendor_b_entries
    group by session_key

),

pairs as (

    select
        vendor_b_sessions.session_key,
        our_sessions.race_id,
        our_sessions.session_type,
        abs(datediff('day', vendor_b_sessions.session_date, our_sessions.session_date)) as day_gap,
        count(distinct iff(our_entries.driver_id is not null, vendor_b_entries.driver_id, null)) as shared_drivers
    from vendor_b_sessions
    inner join our_sessions
        on vendor_b_sessions.season = our_sessions.season
        and vendor_b_sessions.session_type = our_sessions.session_type
        and abs(datediff('day', vendor_b_sessions.session_date, our_sessions.session_date)) <= 3
    left join vendor_b_entries
        on vendor_b_sessions.session_key = vendor_b_entries.session_key
    left join our_entries
        on our_sessions.race_id = our_entries.race_id
        and our_sessions.session_type = our_entries.session_type
        and vendor_b_entries.driver_id = our_entries.driver_id
    group by 1, 2, 3, 4

),

ranked as (

    select
        pairs.*,
        row_number() over (
            partition by pairs.session_key
            order by pairs.shared_drivers desc, pairs.day_gap asc, pairs.race_id asc
        ) as rank_for_session
    from pairs

)

, best as (

    select
        vendor_b_sessions.session_key,
        vendor_b_sessions.session_type,
        vendor_b_sessions.season,
        vendor_b_sessions.session_date,
        coalesce(vendor_b_session_sizes.vendor_b_entries, 0) as vendor_b_entries,
        ranked.race_id,
        coalesce(ranked.shared_drivers, 0) as shared_drivers
    from vendor_b_sessions
    left join vendor_b_session_sizes
        on vendor_b_sessions.session_key = vendor_b_session_sizes.session_key
    left join ranked
        on vendor_b_sessions.session_key = ranked.session_key
        and ranked.rank_for_session = 1

)

select
    best.session_key,
    case
        when best.shared_drivers >= 0.8 * best.vendor_b_entries then best.race_id
    end as race_id,
    best.session_type,
    best.season,
    best.session_date,
    best.shared_drivers,
    best.vendor_b_entries,
    coalesce(our_session_sizes.our_entries, 0) as our_entries
from best
left join our_session_sizes
    on best.race_id = our_session_sizes.race_id
    and best.session_type = our_session_sizes.session_type
