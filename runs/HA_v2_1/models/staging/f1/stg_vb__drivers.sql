select
    {{ clean_null('DRIVER_KEY') }} as driver_key,
    {{ clean_null('FULL_NAME') }} as full_name,
    {{ clean_null('ABBREVIATION') }} as abbreviation,
    {{ clean_null('RACING_NUMBER') }}::int as racing_number
from ({{ dedupe_raw(source('f1_raw', 'VB_DRIVERS'), 'DRIVER_KEY') }})
