{{ config(severity='warn') }}
-- Raw schema drift that the project does not depend on: an unused column that disappeared, or a
-- column that is new to the contract. Returns each difference so it shows up in the build output.
with live_columns as (

    select
        upper(table_name) as table_name,
        upper(column_name) as column_name
    from {{ target.database }}.information_schema.columns
    where table_schema = 'F1_RAW_HC_1'

),

contract as (

    select
        upper(table_name) as table_name,
        upper(column_name) as column_name
    from {{ ref('raw_schema_contract') }}

)

select
    contract.table_name,
    contract.column_name,
    'contract column missing from raw schema (unused)' as problem
from contract
left join live_columns
    on contract.table_name = live_columns.table_name
    and contract.column_name = live_columns.column_name
where live_columns.column_name is null

union all

select
    live_columns.table_name,
    live_columns.column_name,
    'new raw column not in contract' as problem
from live_columns
left join contract
    on live_columns.table_name = contract.table_name
    and live_columns.column_name = contract.column_name
where contract.column_name is null
