-- Results (and other feeds) can reference a driver_id before the driver lands in the
-- raw `drivers` table. Every driver_id seen anywhere gets a row here: the real record
-- when it exists, otherwise a placeholder that is replaced automatically on the
-- first run after the real record arrives.
with drivers as (

    select * from {{ ref('stg_f1__drivers') }}

),

referenced as (

    select driver_id from {{ ref('stg_f1__results') }}
    union
    select driver_id from {{ ref('stg_f1__qualifying') }}
    union
    select driver_id from {{ ref('stg_f1__driver_standings') }}
    union
    select driver_id from {{ ref('stg_f1__lap_times') }}
    union
    select driver_id from {{ ref('stg_f1__pit_stops') }}

),

placeholders as (

    select
        referenced.driver_id,
        'unknown_' || referenced.driver_id as driver_ref,
        'Unknown driver (' || referenced.driver_id || ')' as full_name,
        'Unknown' as first_name,
        'driver (' || referenced.driver_id || ')' as last_name,
        null::varchar as driver_code,
        null::integer as current_number,
        null::varchar as nationality,
        null::date as date_of_birth,
        true as is_placeholder
    from referenced
    left join drivers on drivers.driver_id = referenced.driver_id
    where drivers.driver_id is null

)

select
    driver_id,
    driver_ref,
    full_name,
    first_name,
    last_name,
    driver_code,
    current_number,
    nationality,
    date_of_birth,
    false as is_placeholder
from drivers

union all

select * from placeholders
