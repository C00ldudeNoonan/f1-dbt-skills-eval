{#
    Maps each Vendor B driver (DRIVER_KEY) to our driver_id, automatically, from names.

    Vendor B writes names as "SURNAME Forename" (for example "DE VRIES Nyck"). Both sides are
    normalized with normalize_name (accents folded, letters only). Candidates are:
      1. full_name: normalized Vendor B name equals our surname + forename (exact).
      2. surname_initial: Vendor B name starts with our surname + first letter of our forename
         (catches nicknames such as Alex for Alexander).
    The best match rank wins per driver. If more than one of our drivers still matches, the racing
    number breaks the tie (our permanent_number = Vendor B RACING_NUMBER). Anything still
    unmatched has a null driver_id. The build fails on it (not_null test), so nothing is dropped.
#}
with vb as (

    select
        driver_key,
        full_name,
        abbreviation,
        racing_number,
        {{ normalize_name('full_name') }} as name_key
    from {{ ref('stg_vb__drivers') }}

),

ours as (

    select
        driver_id,
        permanent_number,
        {{ normalize_name('surname') }} as surname_key,
        {{ normalize_name('forename') }} as forename_key
    from {{ ref('stg_f1__drivers') }}

),

candidates as (

    select
        vb.driver_key,
        vb.racing_number,
        ours.driver_id,
        ours.permanent_number,
        case
            when vb.name_key = ours.surname_key || ours.forename_key then 1
            else 2
        end as match_rank,
        case
            when vb.name_key = ours.surname_key || ours.forename_key then 'full_name'
            else 'surname_initial'
        end as match_method
    from vb
    inner join ours
        on vb.name_key like ours.surname_key || left(ours.forename_key, 1) || '%'

),

best_rank as (

    select
        *,
        min(match_rank) over (partition by driver_key) as best_match_rank
    from candidates

),

preferred as (

    select *
    from best_rank
    where match_rank = best_match_rank

),

resolved as (

    select
        driver_key,
        racing_number,
        driver_id,
        permanent_number,
        match_method,
        count(*) over (partition by driver_key) as candidate_count,
        sum(case when permanent_number = racing_number then 1 else 0 end)
            over (partition by driver_key) as number_agreements
    from preferred

),

chosen as (

    select driver_key, driver_id, match_method
    from resolved
    where candidate_count = 1
        or (number_agreements = 1 and permanent_number = racing_number)

)

select
    vb.driver_key,
    chosen.driver_id,
    chosen.match_method,
    vb.full_name as vendor_b_name,
    vb.abbreviation as vendor_b_abbreviation,
    vb.racing_number as vendor_b_racing_number
from {{ ref('stg_vb__drivers') }} as vb
left join chosen
    on vb.driver_key = chosen.driver_key
