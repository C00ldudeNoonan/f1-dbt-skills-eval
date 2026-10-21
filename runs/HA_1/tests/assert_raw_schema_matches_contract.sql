-- Fails when the vendor changes the raw schema. Every column in the contract seed
-- (seeds/f1_raw_expected_columns.csv) must exist in raw, and raw must not contain
-- columns missing from the contract. If the change is intended, update the seed
-- and the staging models that use the column, then rebuild.
with expected as (

    select
        upper(table_name) as table_name,
        upper(column_name) as column_name
    from {{ ref('f1_raw_expected_columns') }}

),

actual as (

    select
        upper(table_name) as table_name,
        upper(column_name) as column_name
    from ANALYTICS_DEV.information_schema.columns
    where table_schema = upper('{{ var("raw_schema") }}')

)

select
    'missing from raw' as problem,
    expected.table_name,
    expected.column_name
from expected
left join actual
    on expected.table_name = actual.table_name
    and expected.column_name = actual.column_name
where actual.column_name is null

union all

select
    'new in raw (not in contract)' as problem,
    actual.table_name,
    actual.column_name
from actual
left join expected
    on actual.table_name = expected.table_name
    and actual.column_name = expected.column_name
where expected.column_name is null
