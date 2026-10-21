{#
    Every pairing of a Vendor B driver with one of our drivers that shares the same normalized
    surname. The name_match flag means surname and given name agree. code_match means the
    surname agrees and the three-letter code agrees. Both feeds write surnames the same way once
    normalized, so this covers spelling and accent differences.
#}
with vb as (

    select
        driver_key,
        abbreviation,
        {{ normalize_text('vb_surname') }} as surname_key,
        {{ normalize_text('vb_given_name') }} as given_key

    from {{ ref('stg_vendor_b__drivers') }}

),

ours as (

    select
        driver_id,
        driver_code,
        {{ normalize_text('surname') }} as surname_key,
        {{ normalize_text('forename') }} as given_key

    from {{ ref('stg_f1__drivers') }}

)

select
    vb.driver_key,
    ours.driver_id,
    vb.surname_key = ours.surname_key and vb.given_key = ours.given_key as name_match,
    vb.surname_key = ours.surname_key and vb.abbreviation = ours.driver_code as code_match

from vb
inner join ours
    on vb.surname_key = ours.surname_key
