{#
    Chooses one driver per Vendor B driver_key, in priority order:
      1. a manual override (seeds/vendor_b_driver_overrides.csv)
      2. exactly one candidate with the same normalized surname and given name
      3. exactly one candidate with the same surname and driver code
    A key that matches none of these, or more than one candidate, gets a NULL driver_id.
    dim_driver_crosswalk then fails the build on that row.
#}
with vb_drivers as (

    select driver_key from {{ ref('stg_vendor_b__drivers') }}

),

candidates as (

    select * from {{ ref('int_vendor_b_driver_candidates') }}

),

name_matches as (

    select driver_key, min(driver_id) as driver_id
    from candidates
    where name_match
    group by driver_key
    having count(*) = 1

),

code_matches as (

    select driver_key, min(driver_id) as driver_id
    from candidates
    where code_match
    group by driver_key
    having count(*) = 1

),

overrides as (

    select driver_key, driver_id from {{ ref('vendor_b_driver_overrides') }}

)

select
    vb_drivers.driver_key,
    coalesce(overrides.driver_id, name_matches.driver_id, code_matches.driver_id) as driver_id,
    case
        when overrides.driver_id is not null then 'manual_override'
        when name_matches.driver_id is not null then 'name'
        when code_matches.driver_id is not null then 'surname_and_code'
    end as match_method

from vb_drivers
left join overrides
    on vb_drivers.driver_key = overrides.driver_key
left join name_matches
    on vb_drivers.driver_key = name_matches.driver_key
left join code_matches
    on vb_drivers.driver_key = code_matches.driver_key
