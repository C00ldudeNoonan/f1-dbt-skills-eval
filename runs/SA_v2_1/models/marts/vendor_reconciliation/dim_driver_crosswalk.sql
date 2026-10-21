-- One row per Vendor B driver, mapped to a primary-feed driver_id. Tiers, best tier wins:
--   0 override            seeds/vendor_b_driver_overrides.csv
--   1 exact_name          accent-folded 'SURNAME Firstname' equals surname+forename
--   2 surname_and_code    vendor name starts with our surname AND the 3-letter code matches
--                         (handles 'Alex' vs 'Alexander')
--   3 code_and_number     same code and same racing number
--   4 surname_prefix      vendor name starts with our surname (unique candidate only)
--   5 results_fingerprint our classified (race, session, position, points) entries equal theirs
--                         for >= 3 entries and >= 80% of theirs
-- Candidates are drivers with results in the seasons Vendor B covers, so namesakes from other
-- eras (Albers, Vergne, Jan Magnussen...) never compete. A tier with several candidates is
-- 'ambiguous'; no candidate is 'unmatched'; both leave driver_id null and fail the build tests.
with vendor_drivers as (

    select * from {{ ref('stg_vendor_b__drivers') }}

),

vendor_seasons as (

    select distinct season from {{ ref('stg_vendor_b__sessions') }}

),

candidates as (

    select
        drivers.driver_id,
        drivers.driver_code,
        drivers.driver_number,
        {{ normalize_name('drivers.surname') }} as surname_key,
        {{ normalize_name("drivers.surname || drivers.forename") }} as name_key
    from {{ ref('stg_ergast__drivers') }} as drivers
    where drivers.driver_id in (
        select driver_id
        from {{ ref('fct_session_results') }}
        where season in (select season from vendor_seasons)
    )

),

vendor_entries as (

    select
        results.driver_key,
        sessions.race_id,
        sessions.session_type,
        results.finish_position,
        results.points
    from {{ ref('stg_vendor_b__results') }} as results
    inner join {{ ref('dim_session_crosswalk') }} as sessions
        on results.session_key = sessions.session_key
    where results.finish_position is not null
        and sessions.race_id is not null

),

fingerprints as (

    select
        vendor_entries.driver_key,
        ours.driver_id,
        count(*) as matching_entries
    from vendor_entries
    inner join {{ ref('fct_session_results') }} as ours
        on ours.race_id = vendor_entries.race_id
        and ours.session_type = vendor_entries.session_type
        and ours.finish_position = vendor_entries.finish_position
        and ours.points = vendor_entries.points
    group by vendor_entries.driver_key, ours.driver_id

),

vendor_entry_counts as (

    select driver_key, count(*) as n_entries from vendor_entries group by driver_key

),

tiered as (

    select v.driver_key, c.driver_id, 1 as tier, 'exact_name' as method
    from vendor_drivers as v inner join candidates as c on v.name_key = c.name_key

    union all

    select v.driver_key, c.driver_id, 2, 'surname_and_code'
    from vendor_drivers as v
    inner join candidates as c
        on startswith(v.name_key, c.surname_key) and v.driver_code = c.driver_code

    union all

    select v.driver_key, c.driver_id, 3, 'code_and_number'
    from vendor_drivers as v
    inner join candidates as c
        on v.driver_code = c.driver_code and v.racing_number = c.driver_number

    union all

    select v.driver_key, c.driver_id, 4, 'surname_prefix'
    from vendor_drivers as v
    inner join candidates as c on startswith(v.name_key, c.surname_key)

    union all

    select f.driver_key, f.driver_id, 5, 'results_fingerprint'
    from fingerprints as f
    inner join vendor_entry_counts as n on n.driver_key = f.driver_key
    where f.matching_entries >= 3 and f.matching_entries >= 0.8 * n.n_entries

    union all

    select driver_key, driver_id, 0, 'override'
    from {{ ref('vendor_b_driver_overrides') }}

),

best_tier as (

    select driver_key, min(tier) as tier
    from tiered
    group by driver_key

),

resolved as (

    select
        tiered.driver_key,
        tiered.method,
        count(distinct tiered.driver_id) as n_candidates,
        min(tiered.driver_id) as driver_id
    from tiered
    inner join best_tier
        on tiered.driver_key = best_tier.driver_key
        and tiered.tier = best_tier.tier
    group by tiered.driver_key, tiered.method

)

select
    vendor_drivers.driver_key,
    case when resolved.n_candidates = 1 then resolved.driver_id end as driver_id,
    vendor_drivers.full_name as vendor_full_name,
    case
        when resolved.driver_key is null then 'unmatched'
        when resolved.n_candidates > 1 then 'ambiguous'
        else resolved.method
    end as match_method,
    coalesce(resolved.n_candidates, 0) as n_candidates,
    coalesce(fingerprints.matching_entries, 0) / nullif(vendor_entry_counts.n_entries, 0) as results_agreement
from vendor_drivers
left join resolved on resolved.driver_key = vendor_drivers.driver_key
left join fingerprints
    on fingerprints.driver_key = vendor_drivers.driver_key
    and fingerprints.driver_id = resolved.driver_id
    and resolved.n_candidates = 1
left join vendor_entry_counts on vendor_entry_counts.driver_key = vendor_drivers.driver_key
