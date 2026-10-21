{#
    One row per Vendor B driver, with the matching driver_id from our project (driver_id null when no single match).

    How a Vendor B driver is matched (automatic, no id lists):
      1. Surname: letters only, accents folded, upper case. Must be equal (DE VRIES matches de Vries).
      2. Given name: letters only, accents folded, upper case. Must be equal, or one must be a prefix of the other
         (ALEX matches Alexander).
      3. Score: +2 for an equal given name, +1 for a prefix match, +1 when the three-letter code agrees with ours.
         The highest score wins. If two of our drivers tie at the top, the driver stays unmatched, and the build
         fails on the not_null test unless a manual override exists.
    A manual override in seeds/vendor_b_driver_overrides.csv takes precedence over the automatic rules.
#}
with vendor_b as (

    select
        driver_key,
        full_name,
        abbreviation,
        upper(regexp_replace({{ fold_accents('surname') }}, '[^A-Za-z]', '')) as surname_key,
        upper(regexp_replace({{ fold_accents('given_name') }}, '[^A-Za-z]', '')) as given_key
    from {{ ref('stg_f1__vb_drivers') }}

),

our_drivers as (

    select
        driver_id,
        driver_code,
        upper(regexp_replace({{ fold_accents('surname') }}, '[^A-Za-z]', '')) as surname_key,
        upper(regexp_replace({{ fold_accents('forename') }}, '[^A-Za-z]', '')) as given_key
    from {{ ref('stg_f1__drivers') }}

),

candidates as (

    select
        vendor_b.driver_key,
        our_drivers.driver_id,
        vendor_b.given_key = our_drivers.given_key as exact_given_name,
        vendor_b.abbreviation = our_drivers.driver_code as code_matches,
        case
            when vendor_b.given_key = our_drivers.given_key then 2
            else 1
        end + iff(vendor_b.abbreviation = our_drivers.driver_code, 1, 0) as match_score
    from vendor_b
    inner join our_drivers
        on vendor_b.surname_key = our_drivers.surname_key
    where vendor_b.given_key = our_drivers.given_key
        or startswith(our_drivers.given_key, vendor_b.given_key)
        or startswith(vendor_b.given_key, our_drivers.given_key)

),

best_candidates as (

    select
        driver_key,
        max(match_score) as best_score
    from candidates
    group by driver_key

),

automatic as (

    select
        candidates.driver_key,
        iff(count(distinct candidates.driver_id) = 1, min(candidates.driver_id), null) as driver_id,
        max(candidates.match_score) as match_score,
        max(candidates.exact_given_name) as exact_given_name,
        max(candidates.code_matches) as code_matches,
        count(distinct candidates.driver_id) as candidate_count
    from candidates
    inner join best_candidates
        on candidates.driver_key = best_candidates.driver_key
        and candidates.match_score = best_candidates.best_score
    group by candidates.driver_key

),

overrides as (

    select
        vendor_b_driver_key as driver_key,
        driver_id
    from {{ ref('vendor_b_driver_overrides') }}

)

select
    vendor_b.driver_key,
    vendor_b.full_name,
    vendor_b.abbreviation,
    coalesce(overrides.driver_id, automatic.driver_id) as driver_id,
    case
        when overrides.driver_id is not null then 'manual override'
        when automatic.driver_id is null then 'unmatched'
        when automatic.exact_given_name and automatic.code_matches then 'surname, given name and code'
        when automatic.exact_given_name then 'surname and given name'
        when automatic.code_matches then 'surname, given name prefix and code'
        else 'surname and given name prefix'
    end as match_method,
    coalesce(automatic.candidate_count, 0) as candidate_count
from vendor_b
left join automatic
    on vendor_b.driver_key = automatic.driver_key
left join overrides
    on vendor_b.driver_key = overrides.driver_key
