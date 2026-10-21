-- One row per Vendor B session, mapped to a primary-feed race_id.
--   race sessions : same season and the primary race date within one day of the session's UTC date
--                   (late-evening local races fall on the next UTC day); the closest date wins.
--   sprint sessions: the Vendor B race session of the same season and meeting whose date falls
--                   0-4 days after the sprint, then that session's race_id.
--   overrides     : seeds/vendor_b_session_overrides.csv wins over both rules.
-- Anything not resolved to exactly one race has a null race_id and fails the not_null test.
with sessions as (

    select * from {{ ref('stg_vendor_b__sessions') }}

),

races as (

    select race_id, season, race_date from {{ ref('stg_ergast__races') }}

),

race_candidates as (

    select
        sessions.session_key,
        races.race_id,
        abs(datediff('day', races.race_date, sessions.session_date)) as day_gap
    from sessions
    inner join races
        on races.season = sessions.season
        and abs(datediff('day', races.race_date, sessions.session_date)) <= 1
    where sessions.session_type = 'race'

),

race_matches as (

    select
        session_key,
        max_by(race_id, -day_gap) as race_id
    from (
        select *, min(day_gap) over (partition by session_key) as min_gap from race_candidates
    )
    group by session_key
    having count_if(day_gap = min_gap) = 1

),

sprint_matches as (

    select
        sprint.session_key,
        max(race_matches.race_id) as race_id,
        count(distinct race_matches.race_id) as n_candidates
    from sessions as sprint
    inner join sessions as race_session
        on race_session.session_type = 'race'
        and race_session.season = sprint.season
        and race_session.meeting_name = sprint.meeting_name
        and datediff('day', sprint.session_date, race_session.session_date) between 0 and 4
    inner join race_matches on race_matches.session_key = race_session.session_key
    where sprint.session_type = 'sprint'
    group by sprint.session_key
    having count(distinct race_matches.race_id) = 1

),

overrides as (

    select session_key, race_id from {{ ref('vendor_b_session_overrides') }}

)

select
    sessions.session_key,
    sessions.session_type,
    coalesce(overrides.race_id, race_matches.race_id, sprint_matches.race_id) as race_id,
    sessions.season,
    case
        when overrides.race_id is not null then 'override'
        when race_matches.race_id is not null then 'race_date'
        when sprint_matches.race_id is not null then 'sprint_meeting_and_date'
        else 'unmatched'
    end as match_method
from sessions
left join overrides on overrides.session_key = sessions.session_key
left join race_matches on race_matches.session_key = sessions.session_key
left join sprint_matches on sprint_matches.session_key = sessions.session_key
