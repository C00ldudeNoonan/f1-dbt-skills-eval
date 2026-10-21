-- Maps each Vendor B driver to one of our drivers by combining evidence per candidate pair:
--   * results fingerprint: Vendor B result rows (via dim_session_crosswalk) that agree with our
--     feed on race, session type and grid slot (+1 each);
--   * surname equal (+10), driver code equal (+10), first name equal or a prefix of the
--     other, e.g. Alex / Alexander (+5), all accent- and case-insensitive.
-- The best-scoring candidate wins if it strictly beats the runner-up; otherwise (ties, no
-- evidence) the driver stays unmatched (driver_id null) and the not_null test stops the build.
-- Racing numbers are not used: they are not stable across seasons.
-- A manual override in the seed always wins.
with vb_drivers as (

    select * from {{ ref('stg_f1__vb_drivers') }}

),

our_drivers as (

    select * from {{ ref('int_f1__drivers_with_placeholders') }}

),

vb_entries as (

    select
        results.driver_key,
        sessions.race_id,
        sessions.session_type,
        results.grid
    from {{ ref('stg_f1__vb_results') }} as results
    inner join {{ ref('dim_session_crosswalk') }} as sessions
        on sessions.session_key = results.session_key

),

our_entries as (

    select race_id, session_type, driver_id, grid
    from {{ ref('fct_session_results') }}

),

fingerprint as (

    select
        vb_entries.driver_key,
        our_entries.driver_id,
        count(*) as grid_matches
    from vb_entries
    inner join our_entries
        on our_entries.race_id = vb_entries.race_id
        and our_entries.session_type = vb_entries.session_type
        and our_entries.grid = vb_entries.grid
    group by vb_entries.driver_key, our_entries.driver_id

),

names as (

    select
        vb_drivers.driver_key,
        our_drivers.driver_id,
        coalesce(vb_drivers.surname collate 'en-ci-ai' = our_drivers.last_name collate 'en-ci-ai', false) as surname_match,
        coalesce(vb_drivers.driver_code = our_drivers.driver_code, false) as code_match,
        coalesce(
            lower(vb_drivers.first_name) collate 'en-ci-ai' = lower(our_drivers.first_name) collate 'en-ci-ai'
            or startswith(lower(our_drivers.first_name) collate 'en-ci-ai', lower(vb_drivers.first_name) collate 'en-ci-ai')
            or startswith(lower(vb_drivers.first_name) collate 'en-ci-ai', lower(our_drivers.first_name) collate 'en-ci-ai'),
            false
        ) as first_name_match
    from vb_drivers
    cross join our_drivers

),

scored as (

    select
        names.driver_key,
        names.driver_id,
        coalesce(fingerprint.grid_matches, 0)
            + iff(names.surname_match, 10, 0)
            + iff(names.code_match, 10, 0)
            + iff(names.first_name_match, 5, 0) as score
    from names
    left join fingerprint
        on fingerprint.driver_key = names.driver_key
        and fingerprint.driver_id = names.driver_id
    where coalesce(fingerprint.grid_matches, 0) > 0 or names.surname_match or names.code_match

),

ranked as (

    select
        *,
        row_number() over (partition by driver_key order by score desc, driver_id) as rank_in_driver,
        lead(score) over (partition by driver_key order by score desc, driver_id) as runner_up_score
    from scored

),

best as (

    select driver_key, driver_id, score
    from ranked
    where rank_in_driver = 1
        and score > coalesce(runner_up_score, 0)

),

overrides as (

    select * from {{ ref('ref_vendor_b_driver_overrides') }}

)

select
    vb_drivers.driver_key,
    coalesce(overrides.driver_id, best.driver_id)::integer as driver_id,
    case
        when overrides.driver_key is not null then 'override'
        when best.driver_id is not null then 'automatic'
    end as match_method,
    best.score::integer as match_score
from vb_drivers
left join best on best.driver_key = vb_drivers.driver_key
left join overrides on overrides.driver_key = vb_drivers.driver_key
