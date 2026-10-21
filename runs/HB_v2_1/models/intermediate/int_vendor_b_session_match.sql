{#
    Chooses one race weekend per Vendor B session: a manual override first, otherwise the
    single closest candidate. Ties at the closest distance leave race_id NULL.
#}
with sessions as (

    select session_key, session_type from {{ ref('stg_vendor_b__sessions') }}

),

candidates as (

    select *
    from {{ ref('int_vendor_b_session_candidates') }}

),

closest as (

    select
        session_key,
        min(days_apart) as days_apart

    from candidates
    group by session_key

),

auto_matches as (

    select
        candidates.session_key,
        min(candidates.race_id) as race_id

    from candidates
    inner join closest
        on candidates.session_key = closest.session_key
        and candidates.days_apart = closest.days_apart
    group by candidates.session_key
    having count(*) = 1

),

overrides as (

    select session_key, race_id, session_type
    from {{ ref('vendor_b_session_overrides') }}

)

select
    sessions.session_key,
    sessions.session_type,
    coalesce(overrides.race_id, auto_matches.race_id) as race_id,
    case
        when overrides.race_id is not null then 'manual_override'
        when auto_matches.race_id is not null then 'date_location'
    end as match_method

from sessions
left join overrides
    on sessions.session_key = overrides.session_key
left join auto_matches
    on sessions.session_key = auto_matches.session_key
