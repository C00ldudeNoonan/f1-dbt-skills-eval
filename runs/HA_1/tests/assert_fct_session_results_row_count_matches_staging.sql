-- Fails if a join in fct_session_results fans out or drops rows. Every GP and sprint result must appear exactly once.
with staging_count as (

    select
        (select count(*) from {{ ref('stg_f1__results') }})
        + (select count(*) from {{ ref('stg_f1__sprint_results') }}) as n

),

mart_count as (

    select count(*) as n from {{ ref('fct_session_results') }}

)

select
    staging_count.n as staging_rows,
    mart_count.n as mart_rows
from staging_count
cross join mart_count
where staging_count.n <> mart_count.n
