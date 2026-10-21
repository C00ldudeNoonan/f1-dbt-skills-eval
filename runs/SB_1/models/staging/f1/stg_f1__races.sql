select
    raceid::int                         as race_id,
    year::int                           as season,
    round::int                          as round,
    circuitid::int                      as circuit_id,
    name                                as race_name,
    date::date                          as race_date
from {{ source('f1_raw', 'races') }}
