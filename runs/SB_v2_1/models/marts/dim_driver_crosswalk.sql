-- Grain: one row per Vendor B driver. Maps Vendor B's `driver_key` to our `driver_id`.
-- driver_id is null (and the not_null test fails the build) when a driver cannot be matched safely.
--
-- Matching, in priority order, among OUR drivers who raced in the seasons Vendor B covers:
--   1. manual override seed (vendor_b_driver_overrides)
--   2. normalized full name (accent-, case- and word-order-insensitive: 'HULKENBERG Nico' = 'Nico Hülkenberg')
--   3. three-letter abbreviation = our driver code (covers nickname differences like Alex / Alexander Albon)
-- A tier only matches when it points to exactly one of our drivers; if name and abbreviation point to
-- different drivers the match is treated as ambiguous and left unmatched. Racing numbers are not used:
-- they are reused by different drivers (e.g. 3 = Ricciardo and Verstappen).
with candidates as (
    select
        drivers.driver_id,
        drivers.driver_code,
        {{ name_key('drivers.full_name') }} as name_key
    from {{ ref('stg_f1__drivers') }} as drivers
    where drivers.driver_id in (
        select results.driver_id
        from {{ ref('fct_results') }} as results
        cross join {{ ref('int_vendor_b_window') }} as win
        where results.season between win.first_season and win.last_season
    )
),

by_name as (
    select vb.driver_key, min(candidates.driver_id) as driver_id, count(*) as hits
    from {{ ref('stg_f1__vb_drivers') }} as vb
    inner join candidates on candidates.name_key = vb.name_key
    group by 1
),

by_code as (
    select vb.driver_key, min(candidates.driver_id) as driver_id, count(*) as hits
    from {{ ref('stg_f1__vb_drivers') }} as vb
    inner join candidates on candidates.driver_code = vb.abbreviation
    group by 1
),

resolved as (
    select
        vb.driver_key,
        overrides.driver_id as override_id,
        iff(by_name.hits = 1, by_name.driver_id, null) as name_id,
        iff(by_code.hits = 1, by_code.driver_id, null) as code_id
    from {{ ref('stg_f1__vb_drivers') }} as vb
    left join {{ ref('vendor_b_driver_overrides') }} as overrides on overrides.driver_key = vb.driver_key
    left join by_name on by_name.driver_key = vb.driver_key
    left join by_code on by_code.driver_key = vb.driver_key
)

select
    driver_key,
    case
        when override_id is not null then override_id
        when name_id is not null and (code_id is null or code_id = name_id) then name_id
        when name_id is null and code_id is not null then code_id
    end::integer as driver_id,
    case
        when override_id is not null then 'override'
        when name_id is not null and (code_id is null or code_id = name_id) then 'name'
        when name_id is null and code_id is not null then 'abbreviation'
        when name_id is not null and code_id is not null then 'ambiguous'
        else 'unmatched'
    end as match_method
from resolved
