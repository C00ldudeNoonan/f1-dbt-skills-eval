{{ config(severity='error') }}
-- Every column this project reads must exist in the raw schema. Returns missing columns.
-- A failure here means the vendor changed the raw shape: fix the staging models, then update
-- seeds/raw_schema_contract.csv.
with live_columns as (

    select
        upper(table_name) as table_name,
        upper(column_name) as column_name
    from {{ target.database }}.information_schema.columns
    where table_schema = 'F1_RAW_HC_1'

)

select
    contract.table_name,
    contract.column_name,
    'required column missing from raw schema' as problem
from {{ ref('raw_schema_contract') }} as contract
left join live_columns
    on upper(contract.table_name) = live_columns.table_name
    and upper(contract.column_name) = live_columns.column_name
where contract.required
    and live_columns.column_name is null
