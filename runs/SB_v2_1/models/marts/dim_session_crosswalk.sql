-- Grain: one row per Vendor B session. Maps `session_key` to our `race_id` and the session type.
-- race_id is null (and the not_null test fails the build) when no unique race is found.
--
-- Matching, in priority order:
--   1. manual override seed (vendor_b_session_overrides)
--   2. date: same season, and the Vendor B UTC start date within one day of our race date (race sessions)
--      or sprint date (sprint sessions). One day of tolerance covers late-evening local starts whose UTC
--      date rolls over. The nearest date wins; a remaining tie is broken by meeting name = circuit location.
with candidates as (
    select
        vb.session_key,
        races.race_id,
        abs(datediff('day', vb.session_date,
            case vb.session_type when 'sprint' then races.sprint_date else races.race_date end)) as day_diff,
        lower(vb.meeting_name) = lower(circuits.location) as same_location
    from {{ ref('stg_f1__vb_sessions') }} as vb
    inner join {{ ref('stg_f1__races') }} as races on races.season = vb.season
    left join {{ ref('stg_f1__circuits') }} as circuits on circuits.circuit_id = races.circuit_id
    where abs(datediff('day', vb.session_date,
            case vb.session_type when 'sprint' then races.sprint_date else races.race_date end)) <= 1
),

ranked as (
    select
        *,
        row_number() over (partition by session_key order by day_diff, same_location desc) as rn,
        count(*) over (partition by session_key, day_diff, same_location) as ties
    from candidates
),

best as (
    select session_key, race_id from ranked where rn = 1 and ties = 1
)

select
    vb.session_key,
    coalesce(overrides.race_id, best.race_id)::integer as race_id,
    vb.session_type,
    case
        when overrides.race_id is not null then 'override'
        when best.race_id is not null then 'date'
        else 'unmatched'
    end as match_method
from {{ ref('stg_f1__vb_sessions') }} as vb
left join {{ ref('vendor_b_session_overrides') }} as overrides on overrides.session_key = vb.session_key
left join best on best.session_key = vb.session_key
