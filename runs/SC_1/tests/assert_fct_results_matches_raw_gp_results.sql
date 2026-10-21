-- fct_results must keep every raw Grand Prix result row (no fan-out, no dropped rows).
select 1
from (
    select
        (select count(*) from {{ source('f1_raw', 'results') }}) as raw_rows,
        (select count(*) from {{ ref('fct_results') }}) as fct_rows
)
where raw_rows <> fct_rows
