-- fct_results must have exactly one row per distinct raw result: no fan-out
-- from dimension joins, no rows lost to them.
with raw_results as (

    select count(distinct resultid) as n from {{ source('ergast', 'results') }}

),

fact as (

    select count(*) as n from {{ ref('fct_results') }}

)

select raw_results.n as raw_results, fact.n as fct_results
from raw_results
cross join fact
where raw_results.n != fact.n
