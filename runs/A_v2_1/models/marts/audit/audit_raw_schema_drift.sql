{{ config(materialized='view') }}

-- Live comparison of the raw schema with seeds/raw_schema_contract.csv: one
-- row per difference. Empty means the vendor's layout matches what staging
-- expects. Being a view, it reflects the raw schema at query time.
{%- set raw = source('ergast', 'races') %}

with contract as (

    select lower(table_name) as table_name, lower(column_name) as column_name, ordinal_position
    from {{ ref('raw_schema_contract') }}

),

live as (

    select lower(table_name) as table_name, lower(column_name) as column_name, ordinal_position
    from {{ raw.database }}.information_schema.columns
    where table_schema = upper('{{ raw.schema }}')

),

contract_tables as (

    select distinct table_name from contract

),

live_tables as (

    select distinct table_name from live

)

select
    coalesce(contract.table_name, live.table_name) as table_name,
    coalesce(contract.column_name, live.column_name) as column_name,
    case
        when live.table_name is null and live_tables.table_name is null then 'table missing'
        when live.table_name is null then 'column missing'
        when contract.table_name is null and contract_tables.table_name is null then 'unexpected table'
        when contract.table_name is null then 'unexpected column'
        else 'column moved'
    end as drift_type,
    contract.ordinal_position as expected_position,
    live.ordinal_position as live_position
from contract
full outer join live
    on contract.table_name = live.table_name
    and contract.column_name = live.column_name
left join live_tables
    on contract.table_name = live_tables.table_name
left join contract_tables
    on live.table_name = contract_tables.table_name
where contract.column_name is null
    or live.column_name is null
    or contract.ordinal_position != live.ordinal_position
