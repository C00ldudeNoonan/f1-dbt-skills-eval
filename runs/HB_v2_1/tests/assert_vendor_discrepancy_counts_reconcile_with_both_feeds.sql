{#
    For the covered seasons, our entries and Vendor B entries must reconcile with the
    discrepancy mart: ours minus missing_in_vendor_b equals Vendor B minus missing_in_vendor_a,
    which is the set of entries both feeds share. This catches a join that drops rows.
#}
with coverage as (

    select min(season) as first_season, max(season) as last_season
    from {{ ref('stg_vendor_b__sessions') }}

),

ours as (

    select count(*) as n
    from {{ ref('fct_session_results') }} as results
    cross join coverage
    where results.season between coverage.first_season and coverage.last_season

),

vendor_b as (

    select count(*) as n
    from {{ ref('stg_vendor_b__results') }}

),

discrepancies as (

    select
        count_if(discrepancy_type = 'missing_in_vendor_b') as missing_b,
        count_if(discrepancy_type = 'missing_in_vendor_a') as missing_a

    from {{ ref('mart_vendor_result_discrepancies') }}

),

shared as (

    select
        ours.n - discrepancies.missing_b as shared_from_ours,
        vendor_b.n - discrepancies.missing_a as shared_from_vendor_b

    from ours
    cross join vendor_b
    cross join discrepancies

)

select *
from shared
where shared_from_ours <> shared_from_vendor_b
