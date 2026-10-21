-- After a run, the incremental table should hold every raw lap exactly once.
select 1
from (
    select
        (select count(*) from {{ source('f1_raw', 'lap_times') }}) as raw_rows,
        (select count(*) from {{ ref('fct_lap_times') }}) as fct_rows
)
where raw_rows <> fct_rows
