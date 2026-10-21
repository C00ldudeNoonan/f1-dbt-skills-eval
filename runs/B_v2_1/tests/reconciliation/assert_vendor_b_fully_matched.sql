-- VENDOR B MATCHING FAILED if this returns rows: these Vendor B drivers or
-- sessions could not be mapped to our ids automatically (no candidate, a weak
-- match, or a tie). The discrepancy mart is skipped until they are resolved.
-- Fix: check the data, or add a row with a reason to
-- seeds/vendor_b_driver_overrides.csv / seeds/vendor_b_session_overrides.csv.
select 'driver' as kind, driver_key as vendor_b_key, vendor_b_full_name as detail
from {{ ref('dim_driver_crosswalk') }}
where driver_id is null

union all

select 'session', session_key::varchar, session_type || ' ' || season || ' ' || meeting_name || ' on ' || session_date
from {{ ref('dim_session_crosswalk') }}
where race_id is null
