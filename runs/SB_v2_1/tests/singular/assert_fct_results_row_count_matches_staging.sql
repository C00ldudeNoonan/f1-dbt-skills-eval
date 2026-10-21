-- Joins in fct_results must never add or drop rows (a duplicated dimension row once doubled Ferrari).
select staged.n as staged_rows, modelled.n as fct_rows
from (select count(*) as n from {{ ref('stg_f1__results') }}) as staged
cross join (select count(*) as n from {{ ref('fct_results') }}) as modelled
where staged.n <> modelled.n
