{#-
  One row per Vendor B driver mapped to our driver_id.

  Automatic rule:
    1. Candidates are our drivers who have an entry in the same sessions
       (via dim_session_crosswalk) as the Vendor B driver.
    2. Each candidate is scored on identity attributes:
         surname (accent/case/space-insensitive) 3, driver code 2,
         car number 1, forename 1.
    3. The top-scoring candidate is accepted if it scores >= 4 (e.g. surname
       plus one more attribute), is the only candidate with that score, and
       shares at least half of the Vendor B driver's sessions.
  Car codes and numbers are reused across eras (MSC, VER, number 3 ...), which
  is why co-participation in the same sessions and the surname are required.
  vendor_b_driver_overrides wins over the automatic match. Unmatched or
  ambiguous drivers get a null driver_id and fail the build.
-#}
with vb_drivers as (
    select * from {{ ref('stg_vendor_b__drivers') }}
),

vb_entries as (
    select
        results.driver_key,
        sessions.race_id,
        sessions.session_type
    from {{ ref('stg_vendor_b__results') }} as results
    inner join {{ ref('dim_session_crosswalk') }} as sessions
        on results.session_key = sessions.session_key
    where sessions.race_id is not null
),

vb_session_counts as (
    select driver_key, count(*) as vb_sessions
    from vb_entries
    group by driver_key
),

our_entries as (
    select distinct race_id, session_type, driver_id
    from {{ ref('fct_session_results') }}
),

shared as (
    select
        vb_entries.driver_key,
        our_entries.driver_id,
        count(*) as shared_sessions
    from vb_entries
    inner join our_entries
        on vb_entries.race_id = our_entries.race_id
        and vb_entries.session_type = our_entries.session_type
    group by 1, 2
),

scored as (
    select
        shared.driver_key,
        shared.driver_id,
        shared.shared_sessions,
        vb_session_counts.vb_sessions,
        {{ name_key('vb.surname') }} = {{ name_key('ours.surname') }}           as surname_matches,
        vb.driver_code = ours.driver_code                                       as code_matches,
        vb.racing_number = ours.permanent_number                                as number_matches,
        {{ name_key('vb.forename') }} = {{ name_key('ours.forename') }}         as forename_matches
    from shared
    inner join vb_session_counts
        on shared.driver_key = vb_session_counts.driver_key
    inner join vb_drivers as vb
        on shared.driver_key = vb.driver_key
    inner join {{ ref('stg_ergast__drivers') }} as ours
        on shared.driver_id = ours.driver_id
),

ranked as (
    select
        *,
        iff(surname_matches, 3, 0) + iff(coalesce(code_matches, false), 2, 0)
            + iff(coalesce(number_matches, false), 1, 0) + iff(forename_matches, 1, 0)   as match_score,
        row_number() over (partition by driver_key order by match_score desc, shared_sessions desc, driver_id) as rn,
        count(*) over (partition by driver_key, match_score)                              as candidates_at_score
    from scored
),

automatic as (
    select *
    from ranked
    where rn = 1
        and match_score >= 4
        and candidates_at_score = 1
        and shared_sessions * 2 >= vb_sessions
),

overrides as (
    select * from {{ ref('vendor_b_driver_overrides') }}
)

select
    vb_drivers.driver_key,
    coalesce(overrides.driver_id, automatic.driver_id)  as driver_id,
    vb_drivers.full_name                                as vendor_b_full_name,
    vb_drivers.driver_code                              as vendor_b_driver_code,
    case
        when overrides.driver_key is not null then 'override'
        when automatic.driver_id is not null then 'scored'
        else 'unmatched'
    end                                                 as match_method,
    automatic.match_score,
    automatic.shared_sessions,
    automatic.vb_sessions
from vb_drivers
left join automatic
    on vb_drivers.driver_key = automatic.driver_key
left join overrides
    on vb_drivers.driver_key = overrides.driver_key
