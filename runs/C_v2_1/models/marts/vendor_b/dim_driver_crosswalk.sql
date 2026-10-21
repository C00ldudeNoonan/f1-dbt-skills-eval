-- Maps every Vendor B driver to our driver_id. Vendor B shares no ids with
-- us, and no single attribute is a safe key: racing numbers are reused (3,
-- 2 and 9 each belong to two drivers), names are unaccented or shortened
-- ('PEREZ', 'ALBON Alex'), and codes repeat across eras ('VER'). The match
-- uses two kinds of evidence:
--   1. Candidates are our drivers with an entry in at least one of the same
--      (crosswalked) sessions as the Vendor B driver. That rules out
--      other-era namesakes.
--   2. Identity score, 0 to 4: one point each for the same code, the same
--      surname, the same forename (names compared ignoring accents and case)
--      and racing number = our permanent number.
--   3. Agreement: shared sessions where both feeds have the same grid slot or
--      the same finishing position.
-- Candidates are ranked by identity score, then agreement. The best one is
-- accepted only when it has at least one identity point, agrees in at least
-- half of the Vendor B driver's sessions, and strictly beats the runner-up.
-- Otherwise the driver is unmatched, and the not_null test on driver_id fails
-- the build until the feed is fixed or a vendor_b_driver_overrides row is added.

with vendor_drivers as (
    select * from {{ ref('stg_vendor_b__drivers') }}
),

overrides as (
    select * from {{ ref('vendor_b_driver_overrides') }}
),

sessions as (
    select * from {{ ref('dim_session_crosswalk') }}
    where race_id is not null
),

vendor_entries as (
    select
        sessions.race_id,
        sessions.session_type,
        vendor_results.driver_key,
        vendor_results.grid,
        vendor_results.finish_position
    from {{ ref('stg_vendor_b__results') }} as vendor_results
    inner join sessions
        on vendor_results.session_key = sessions.session_key
),

vendor_session_counts as (
    select
        driver_key,
        count(*) as vendor_sessions
    from vendor_entries
    group by driver_key
),

our_entries as (
    select
        race_id,
        session_type,
        driver_id,
        grid,
        finish_position
    from {{ ref('fct_session_results') }}
),

shared_evidence as (
    select
        vendor_entries.driver_key,
        our_entries.driver_id,
        count(*) as shared_sessions,
        count_if(
            vendor_entries.grid = our_entries.grid
            or vendor_entries.finish_position = our_entries.finish_position
        ) as agreeing_sessions
    from vendor_entries
    inner join our_entries
        on vendor_entries.race_id = our_entries.race_id
        and vendor_entries.session_type = our_entries.session_type
    group by vendor_entries.driver_key, our_entries.driver_id
),

scored as (
    select
        shared_evidence.driver_key,
        shared_evidence.driver_id,
        shared_evidence.shared_sessions,
        shared_evidence.agreeing_sessions,
        vendor_session_counts.vendor_sessions,
        (iff(vendor_drivers.driver_code = our_drivers.driver_code, 1, 0)
            + iff(collate(vendor_drivers.surname, 'en-ai-ci') = collate(our_drivers.surname, 'en-ai-ci'), 1, 0)
            + iff(collate(vendor_drivers.forename, 'en-ai-ci') = collate(our_drivers.forename, 'en-ai-ci'), 1, 0)
            + iff(vendor_drivers.racing_number = our_drivers.permanent_number, 1, 0)
        ) as identity_score
    from shared_evidence
    inner join vendor_session_counts
        on shared_evidence.driver_key = vendor_session_counts.driver_key
    inner join vendor_drivers
        on shared_evidence.driver_key = vendor_drivers.driver_key
    inner join {{ ref('stg_f1__drivers') }} as our_drivers
        on shared_evidence.driver_id = our_drivers.driver_id
),

ranked as (
    select
        *,
        row_number() over (
            partition by driver_key
            order by identity_score desc, agreeing_sessions desc, driver_id
        ) as candidate_rank,
        lead(identity_score) over (
            partition by driver_key
            order by identity_score desc, agreeing_sessions desc, driver_id
        ) as runner_up_identity_score,
        lead(agreeing_sessions) over (
            partition by driver_key
            order by identity_score desc, agreeing_sessions desc, driver_id
        ) as runner_up_agreeing_sessions
    from scored
),

automatic_matches as (
    select *
    from ranked
    where candidate_rank = 1
        and identity_score >= 1
        and agreeing_sessions * 2 >= vendor_sessions
        and (
            runner_up_identity_score is null
            or identity_score > runner_up_identity_score
            or (identity_score = runner_up_identity_score
                and agreeing_sessions > runner_up_agreeing_sessions)
        )
),

best_candidates as (
    select * from ranked where candidate_rank = 1
)

select
    vendor_drivers.driver_key,
    coalesce(overrides.driver_id, automatic_matches.driver_id) as driver_id,
    vendor_drivers.full_name as vendor_full_name,
    vendor_drivers.driver_code as vendor_driver_code,
    case
        when overrides.driver_key is not null then 'override'
        when automatic_matches.driver_key is not null then 'automatic'
        else 'unmatched'
    end as match_method,
    best_candidates.identity_score,
    best_candidates.agreeing_sessions,
    best_candidates.vendor_sessions,
    best_candidates.driver_id as best_candidate_driver_id
from vendor_drivers
left join overrides
    on vendor_drivers.driver_key = overrides.driver_key
left join automatic_matches
    on vendor_drivers.driver_key = automatic_matches.driver_key
left join best_candidates
    on vendor_drivers.driver_key = best_candidates.driver_key
