-- One fact row per source result. A join that fans out (for example a duplicated dimension row)
-- makes this count differ.
select
    (select count(*) from {{ ref('stg_f1__results') }}) as source_rows,
    (select count(*) from {{ ref('fct_results') }}) as fact_rows
where (select count(*) from {{ ref('stg_f1__results') }}) <> (select count(*) from {{ ref('fct_results') }})
