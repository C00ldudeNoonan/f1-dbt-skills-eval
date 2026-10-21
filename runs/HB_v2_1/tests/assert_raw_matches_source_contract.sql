{#
    Fails for every raw table or column that differs from seeds/source_contract.csv.
    drift = 'missing' means the contract expects it and the vendor no longer has it.
    drift = 'unexpected' means the vendor has something the contract does not list.
#}
with actual as (

    select
        upper(table_name) as table_name,
        upper(column_name) as column_name

    from {{ var('raw_database') }}.information_schema.columns
    where table_schema = upper('{{ var("raw_schema") }}')

),

expected as (

    select
        upper(table_name) as table_name,
        upper(column_name) as column_name

    from {{ ref('source_contract') }}

)

select
    'missing' as drift,
    expected.table_name,
    expected.column_name

from expected
left join actual
    on expected.table_name = actual.table_name
    and expected.column_name = actual.column_name
where actual.table_name is null

union all

select
    'unexpected' as drift,
    actual.table_name,
    actual.column_name

from actual
left join expected
    on actual.table_name = expected.table_name
    and actual.column_name = expected.column_name
where expected.table_name is null
