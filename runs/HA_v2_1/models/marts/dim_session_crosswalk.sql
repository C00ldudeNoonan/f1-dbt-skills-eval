{#
    Maps each Vendor B session (SESSION_KEY) to our race_id and session_type, automatically.

    A Vendor B session matches one of our sessions when all of these hold:
      - same season (year);
      - same place: Vendor B MEETING_NAME equals the circuit location (both normalized);
      - same day, within one day either way (Vendor B times are UTC, and our date is local).
    Race sessions are matched against every race. Sprint sessions are matched against races that
    have sprint results. Exactly one match is required. Anything else has a null race_id, and the
    build fails (not_null test) rather than guessing.
#}
with races as (

    select
        races.race_id,
        races.season,
        races.race_date,
        {{ normalize_name('circuits.location') }} as location_key
    from {{ ref('stg_f1__races') }} as races
    inner join {{ ref('stg_f1__circuits') }} as circuits
        on races.circuit_id = circuits.circuit_id

),

our_sessions as (

    select race_id, season, race_date, location_key, 'race' as session_type
    from races

    union all

    select races.race_id, races.season, races.race_date, races.location_key, 'sprint' as session_type
    from races
    where races.race_id in (select race_id from {{ ref('stg_f1__sprint_results') }})

),

vb as (

    select
        session_key,
        session_type,
        season,
        session_date,
        meeting_name,
        {{ normalize_name('meeting_name') }} as meeting_key
    from {{ ref('stg_vb__sessions') }}

),

matches as (

    select
        vb.session_key,
        our_sessions.race_id
    from vb
    inner join our_sessions
        on our_sessions.session_type = vb.session_type
        and our_sessions.season = vb.season
        and our_sessions.location_key = vb.meeting_key
        and abs(datediff(day, our_sessions.race_date, vb.session_date)) <= 1

),

match_counts as (

    select session_key, min(race_id) as race_id, count(*) as match_count
    from matches
    group by session_key

)

select
    vb.session_key,
    vb.session_type,
    vb.season,
    vb.meeting_name,
    case when match_counts.match_count = 1 then match_counts.race_id end as race_id,
    coalesce(match_counts.match_count, 0) as match_count
from vb
left join match_counts
    on vb.session_key = match_counts.session_key
