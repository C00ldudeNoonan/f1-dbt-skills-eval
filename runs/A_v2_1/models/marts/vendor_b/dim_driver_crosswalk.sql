{#-
    One row per Vendor B driver, mapped to our driver_id.

    Matching is evidence-based and re-evaluated every run, so new drivers and
    seasons are picked up without maintenance:
      * Candidates: every driver of ours who has a result in at least one of
        the sessions this Vendor B driver appears in (via dim_session_crosswalk).
      * Signals, each scored 0..1:
          grid_agreement  share of this driver's Vendor B entries where the
                          candidate started from the same grid slot in the
                          same session
          code_match      three-letter code equal (e.g. VER)
          name_match      surname equal, ignoring case and accents
      * score = grid_agreement + code_match + name_match (max 3).
      * Accepted when the best candidate scores at least
        var('vendor_b_driver_min_score') (2: at least two strong signals) and
        beats the runner-up by var('vendor_b_driver_min_margin') (1).
      * A row in seeds/vendor_b_driver_overrides.csv takes precedence.
    Anything else gets a null driver_id and fails the not_null test, so the
    build stops and names the driver. Codes are reused across eras (Michael
    and Mick Schumacher are both MSC), which is why codes and names only count
    for drivers who actually raced in the same sessions.
-#}

with vendor_drivers as (

    select * from {{ ref('stg_vendor_b__drivers') }}

),

vendor_entries as (

    select
        results.driver_key,
        sessions.race_id,
        sessions.session_type,
        results.grid
    from {{ ref('stg_vendor_b__results') }} as results
    inner join {{ ref('dim_session_crosswalk') }} as sessions
        on results.session_key = sessions.session_key
    where sessions.race_id is not null

),

our_entries as (

    select race_id, session_type, driver_id, grid
    from {{ ref('fct_session_results') }}

),

evidence as (

    select
        vendor_entries.driver_key,
        our_entries.driver_id,
        count_if(vendor_entries.grid = our_entries.grid) as grid_agreements
    from vendor_entries
    inner join our_entries
        on vendor_entries.race_id = our_entries.race_id
        and vendor_entries.session_type = our_entries.session_type
    group by 1, 2

),

vendor_entry_counts as (

    select driver_key, count(*) as vendor_entries
    from vendor_entries
    group by 1

),

scored as (

    select
        evidence.driver_key,
        evidence.driver_id,
        evidence.grid_agreements / vendor_entry_counts.vendor_entries as grid_agreement,
        coalesce(vendor_drivers.driver_code = drivers.driver_code, false) as code_match,
        coalesce(
            collate(lower(vendor_drivers.surname), 'en-ai') = collate(lower(drivers.surname), 'en-ai'),
            false
        ) as name_match
    from evidence
    inner join vendor_entry_counts
        on evidence.driver_key = vendor_entry_counts.driver_key
    inner join vendor_drivers
        on evidence.driver_key = vendor_drivers.driver_key
    inner join {{ ref('stg_ergast__drivers') }} as drivers
        on evidence.driver_id = drivers.driver_id

),

ranked as (

    select
        *,
        grid_agreement + iff(code_match, 1, 0) + iff(name_match, 1, 0) as score,
        row_number() over (partition by driver_key order by score desc, driver_id) as candidate_rank,
        lead(score) over (partition by driver_key order by score desc, driver_id) as runner_up_score
    from scored

),

automatic as (

    select driver_key, driver_id, score, runner_up_score, grid_agreement, code_match, name_match
    from ranked
    where candidate_rank = 1
        and score >= {{ var('vendor_b_driver_min_score') }}
        and score - coalesce(runner_up_score, 0) >= {{ var('vendor_b_driver_min_margin') }}

),

best_attempt as (

    select driver_key, score, runner_up_score, grid_agreement, code_match, name_match
    from ranked
    where candidate_rank = 1

),

overrides as (

    select overrides.driver_key, drivers.driver_id, 'override: ' || overrides.reason as match_method
    from {{ ref('vendor_b_driver_overrides') }} as overrides
    inner join {{ ref('stg_ergast__drivers') }} as drivers
        on overrides.driver_ref = drivers.driver_ref

)

select
    vendor_drivers.driver_key,
    coalesce(overrides.driver_id, automatic.driver_id) as driver_id,
    vendor_drivers.full_name as vendor_full_name,
    vendor_drivers.driver_code as vendor_driver_code,
    coalesce(overrides.match_method, iff(automatic.driver_id is not null, 'automatic', 'unmatched')) as match_method,
    round(best_attempt.score, 3) as match_score,
    round(best_attempt.runner_up_score, 3) as runner_up_score,
    round(best_attempt.grid_agreement, 3) as grid_agreement,
    best_attempt.code_match,
    best_attempt.name_match
from vendor_drivers
left join overrides
    on vendor_drivers.driver_key = overrides.driver_key
left join automatic
    on vendor_drivers.driver_key = automatic.driver_key
left join best_attempt
    on vendor_drivers.driver_key = best_attempt.driver_key
