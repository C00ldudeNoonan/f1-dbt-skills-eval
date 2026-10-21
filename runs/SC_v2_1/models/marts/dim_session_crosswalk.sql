-- Maps each Vendor B session to one of our races. Matching, in order:
--   1. manual override seed (always wins);
--   2. date: a `race` session starts on the race date (+-1 day for UTC drift); a `sprint`
--      session starts 0-2 days before the race date, on a race that has sprint results;
--   3. when the session has no date: same season + venue (Vendor B meeting name = our circuit
--      location, accent/case-insensitive), sprint sessions only on races with sprints.
-- Several candidates are narrowed by venue; anything still not exactly one is left unmatched
-- (race_id null), which fails the not_null test and stops the build.
with sessions as (

    select * from {{ ref('stg_f1__vb_sessions') }}

),

races as (

    select
        races.race_id,
        races.season,
        races.race_date,
        circuits.location
    from {{ ref('stg_f1__races') }} as races
    left join {{ ref('stg_f1__circuits') }} as circuits on circuits.circuit_id = races.circuit_id

),

sprint_races as (

    select distinct race_id from {{ ref('stg_f1__sprint_results') }}

),

candidates as (

    select
        sessions.session_key,
        races.race_id,
        coalesce(
            sessions.meeting_name collate 'en-ci-ai' = races.location collate 'en-ci-ai',
            false
        ) as venue_match,
        sessions.session_date is not null as has_date
    from sessions
    inner join races on races.season = sessions.season
    where (sessions.session_type = 'race' or races.race_id in (select race_id from sprint_races))
        and sessions.session_type in ('race', 'sprint')
        and case
            when sessions.session_date is null then
                coalesce(sessions.meeting_name collate 'en-ci-ai' = races.location collate 'en-ci-ai', false)
            when sessions.session_type = 'race' then
                abs(datediff(day, races.race_date, sessions.session_date)) <= 1
            else
                datediff(day, races.race_date, sessions.session_date) between -2 and 0
        end

),

-- if several candidates survive, keep the ones that also match on venue
narrowed as (

    select *
    from candidates
    qualify venue_match::integer = max(venue_match::integer) over (partition by session_key)

),

resolved as (

    select
        session_key,
        case when count(*) = 1 then max(race_id) end as race_id,
        count(*) as n_candidates,
        case when max(has_date) then 'date' else 'venue' end as match_method
    from narrowed
    group by session_key

),

overrides as (

    select * from {{ ref('ref_vendor_b_session_overrides') }}

)

select
    sessions.session_key,
    coalesce(overrides.race_id, resolved.race_id)::integer as race_id,
    sessions.session_type,
    case
        when overrides.session_key is not null then 'override'
        when resolved.race_id is not null then resolved.match_method
    end as match_method
from sessions
left join resolved on resolved.session_key = sessions.session_key
left join overrides on overrides.session_key = sessions.session_key
