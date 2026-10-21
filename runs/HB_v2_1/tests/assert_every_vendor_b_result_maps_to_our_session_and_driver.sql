{#
    Every Vendor B result must map to a race and session type through the session crosswalk,
    and to a driver through the driver crosswalk. A result that drops out here would be missing
    from the discrepancy mart without any error, so this checks the counts.
#}
with raw_count as (

    select count(*) as vendor_b_results
    from {{ ref('stg_vendor_b__results') }}

),

mapped_count as (

    select count(*) as mapped_results
    from {{ ref('stg_vendor_b__results') }} as results
    inner join {{ ref('dim_session_crosswalk') }} as sessions
        on results.session_key = sessions.session_key
    inner join {{ ref('dim_driver_crosswalk') }} as drivers
        on results.driver_key = drivers.driver_key

)

select *
from raw_count
cross join mapped_count
where vendor_b_results <> mapped_results
