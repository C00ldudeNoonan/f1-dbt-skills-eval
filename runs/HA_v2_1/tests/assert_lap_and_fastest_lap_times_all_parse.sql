{#
    Every non-null raw fastest-lap time must parse to milliseconds. Returns rows that do not.
#}
select raw.resultid
from {{ source('f1_raw', 'RESULTS') }} as raw
inner join {{ ref('stg_f1__results') }} as stg
    on raw.resultid::int = stg.result_id
where nullif(nullif(trim(raw.fastestlaptime), '\\N'), '') is not null
    and stg.fastest_lap_time_ms is null
