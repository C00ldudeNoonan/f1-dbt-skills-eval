-- Maps every Vendor B session to our race_id and session type. Vendor B
-- shares no ids with us, so the match comes from the data:
--   1. Candidates are our sessions of the same type in the same season,
--      dated within one day of the Vendor B session (allows for UTC versus
--      local-date shifts).
--   2. The candidate must be at the same circuit: Vendor B's meeting name
--      equals our circuit location, ignoring accents and case.
--   3. The closest start time wins. A tie means the match is ambiguous and
--      the session stays unmatched.
-- Rows in the vendor_b_session_overrides seed always win. A session with no
-- confident match keeps a null race_id, and the not_null test fails the build.

with vendor_sessions as (
    select * from {{ ref('stg_vendor_b__sessions') }}
),

overrides as (
    select * from {{ ref('vendor_b_session_overrides') }}
),

our_sessions as (
    select
        races.race_id,
        races.season,
        'race' as session_type,
        races.race_date as session_date,
        timestamp_ntz_from_parts(races.race_date, races.race_time_utc) as session_start_utc,
        circuits.location
    from {{ ref('stg_f1__races') }} as races
    inner join {{ ref('stg_f1__circuits') }} as circuits
        on races.circuit_id = circuits.circuit_id
    union all
    select
        races.race_id,
        races.season,
        'sprint',
        races.sprint_date,
        timestamp_ntz_from_parts(races.sprint_date, races.sprint_time_utc),
        circuits.location
    from {{ ref('stg_f1__races') }} as races
    inner join {{ ref('stg_f1__circuits') }} as circuits
        on races.circuit_id = circuits.circuit_id
    where races.has_sprint
),

candidates as (
    select
        vendor_sessions.session_key,
        our_sessions.race_id,
        our_sessions.session_type,
        abs(datediff(minute,
            coalesce(vendor_sessions.session_start_utc, vendor_sessions.session_date::timestamp_ntz),
            coalesce(our_sessions.session_start_utc, our_sessions.session_date::timestamp_ntz)
        )) as start_difference_minutes
    from vendor_sessions
    inner join our_sessions
        on vendor_sessions.season = our_sessions.season
        and vendor_sessions.session_type = our_sessions.session_type
        and abs(datediff(day, vendor_sessions.session_date, our_sessions.session_date)) <= 1
        and collate(vendor_sessions.meeting_name, 'en-ai-ci') = collate(our_sessions.location, 'en-ai-ci')
),

ranked as (
    select
        *,
        row_number() over (partition by session_key order by start_difference_minutes, race_id) as candidate_rank,
        lead(start_difference_minutes) over (partition by session_key order by start_difference_minutes, race_id) as runner_up_difference
    from candidates
),

automatic_matches as (
    select *
    from ranked
    where candidate_rank = 1
        and (runner_up_difference is null or runner_up_difference > start_difference_minutes)
)

select
    vendor_sessions.session_key,
    coalesce(overrides.race_id, automatic_matches.race_id) as race_id,
    coalesce(overrides.session_type, automatic_matches.session_type) as session_type,
    vendor_sessions.season,
    vendor_sessions.meeting_name,
    vendor_sessions.session_date,
    case
        when overrides.session_key is not null then 'override'
        when automatic_matches.session_key is not null then 'automatic'
        else 'unmatched'
    end as match_method,
    automatic_matches.start_difference_minutes
from vendor_sessions
left join overrides
    on vendor_sessions.session_key = overrides.session_key
left join automatic_matches
    on vendor_sessions.session_key = automatic_matches.session_key
