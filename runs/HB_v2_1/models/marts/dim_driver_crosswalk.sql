{#
    One row per Vendor B driver, mapped to our driver_id. Matching rules are in
    int_vendor_b_driver_match. Every row must have a driver_id: the build fails if a Vendor B
    driver cannot be matched, and tests check the mapping is one-to-one.
#}
select
    driver_key,
    driver_id,
    match_method

from {{ ref('int_vendor_b_driver_match') }}
