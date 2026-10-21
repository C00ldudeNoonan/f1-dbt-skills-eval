{#-
    One row per Vendor B session, mapped to our race_id and session_type.

    Matching (automatic, re-evaluated every run):
      1. Candidates are our sessions (Grand Prix on race_date, sprint on
         sprint_date) with the same season and session type, held within
         var('vendor_b_session_date_tolerance_days') days of Vendor B's UTC
         start date (covers time zones and late-night races).
      2. Venue check: Vendor B's meeting_name is the venue locality, compared
         with our circuit location ignoring case and accents.
      3. The closest date wins among venue matches; if the venue name differs
         (vendor renamed it), a candidate on the exact same date is accepted.
      4. A row in seeds/vendor_b_session_overrides.csv takes precedence.
    A session that matches nothing, or matches two of our sessions equally,
    gets a null race_id and fails the not_null test, so the build stops and
    names it.
-#}
{%- set tolerance = var('vendor_b_session_date_tolerance_days') -%}

with vendor_sessions as (

    select * from {{ ref('stg_vendor_b__sessions') }}

),

our_sessions as (

    select races.race_id, races.season, 'race' as session_type, races.race_date as session_date, circuits.location
    from {{ ref('stg_ergast__races') }} as races
    inner join {{ ref('stg_ergast__circuits') }} as circuits
        on races.circuit_id = circuits.circuit_id

    union all

    select races.race_id, races.season, 'sprint', races.sprint_date, circuits.location
    from {{ ref('stg_ergast__races') }} as races
    inner join {{ ref('stg_ergast__circuits') }} as circuits
        on races.circuit_id = circuits.circuit_id
    where races.sprint_date is not null

),

candidates as (

    select
        vendor_sessions.session_key,
        our_sessions.race_id,
        our_sessions.session_type,
        abs(datediff(day, our_sessions.session_date, vendor_sessions.session_date)) as days_apart,
        collate(lower(trim(vendor_sessions.meeting_name)), 'en-ai')
            = collate(lower(trim(our_sessions.location)), 'en-ai') as venue_match
    from vendor_sessions
    inner join our_sessions
        on vendor_sessions.season = our_sessions.season
        and vendor_sessions.session_type = our_sessions.session_type
        and abs(datediff(day, our_sessions.session_date, vendor_sessions.session_date)) <= {{ tolerance }}

),

eligible as (

    select *
    from candidates
    where venue_match or days_apart = 0

),

ranked as (

    select
        *,
        count(*) over (partition by session_key, venue_match, days_apart) as tied_candidates,
        row_number() over (
            partition by session_key
            order by venue_match desc, days_apart, race_id
        ) as candidate_rank
    from eligible

),

automatic as (

    select
        session_key,
        race_id,
        session_type,
        iff(venue_match, 'automatic: venue and date', 'automatic: date only') as match_method,
        days_apart
    from ranked
    where candidate_rank = 1
        and tied_candidates = 1

),

overrides as (

    select session_key, race_id, session_type, 'override: ' || reason as match_method
    from {{ ref('vendor_b_session_overrides') }}

)

select
    vendor_sessions.session_key,
    coalesce(overrides.race_id, automatic.race_id) as race_id,
    coalesce(overrides.session_type, automatic.session_type, vendor_sessions.session_type) as session_type,
    vendor_sessions.season,
    vendor_sessions.meeting_name,
    vendor_sessions.session_date as vendor_session_date,
    coalesce(overrides.match_method, automatic.match_method, 'unmatched') as match_method,
    automatic.days_apart
from vendor_sessions
left join overrides
    on vendor_sessions.session_key = overrides.session_key
left join automatic
    on vendor_sessions.session_key = automatic.session_key
