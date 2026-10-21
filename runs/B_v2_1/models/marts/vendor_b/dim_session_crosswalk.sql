{#-
  One row per Vendor B session mapped to our race_id and session_type.

  Automatic rule: same season, same session type, and the session's date equals
  our race_date (Grand Prix) or sprint_date (sprint). That is unique: a race
  weekend has one Grand Prix and at most one sprint. The circuit location must
  also agree with Vendor B's meeting name; it's recorded as a check and breaks
  ties if a date ever matches more than one race.
  vendor_b_session_overrides wins over the automatic match.
  Unmatched or ambiguous sessions get a null race_id and fail the build.
-#}
with sessions as (
    select * from {{ ref('stg_vendor_b__sessions') }}
),

races as (
    select
        races.race_id,
        races.season,
        races.race_date,
        races.sprint_date,
        circuits.location
    from {{ ref('stg_ergast__races') }} as races
    left join {{ ref('stg_ergast__circuits') }} as circuits
        on races.circuit_id = circuits.circuit_id
),

candidates as (
    select
        sessions.session_key,
        races.race_id,
        {{ name_key('races.location') }} = {{ name_key('sessions.meeting_name') }} as location_agrees
    from sessions
    inner join races
        on sessions.season = races.season
        and sessions.session_date = iff(sessions.session_type = 'sprint', races.sprint_date, races.race_date)
),

ranked as (
    select
        *,
        count(*) over (partition by session_key)                                        as candidate_count,
        count_if(location_agrees) over (partition by session_key)                       as location_candidate_count,
        row_number() over (partition by session_key order by location_agrees desc, race_id) as rn
    from candidates
),

automatic as (
    select
        session_key,
        race_id,
        location_agrees,
        candidate_count
    from ranked
    where rn = 1
        -- Accept a unique date match, or a unique date + location match among several.
        and (candidate_count = 1 or (location_agrees and location_candidate_count = 1))
),

overrides as (
    select * from {{ ref('vendor_b_session_overrides') }}
)

select
    sessions.session_key,
    coalesce(overrides.race_id, automatic.race_id)                  as race_id,
    coalesce(overrides.session_type, sessions.session_type)         as session_type,
    sessions.season,
    sessions.session_date,
    sessions.meeting_name,
    case
        when overrides.session_key is not null then 'override'
        when automatic.race_id is not null then 'date'
        else 'unmatched'
    end                                                             as match_method,
    automatic.location_agrees,
    coalesce(automatic.candidate_count, 0)                          as candidate_count
from sessions
left join automatic
    on sessions.session_key = automatic.session_key
left join overrides
    on sessions.session_key = overrides.session_key
