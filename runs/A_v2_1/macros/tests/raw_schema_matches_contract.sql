{#-
    Compares a raw source table's live columns (information_schema) with the
    expected layout in seeds/raw_schema_contract.csv.

    check='missing'     fails for every contracted column the table no longer
                        has. A renamed or dropped table shows up as all of its
                        columns missing. Use with severity error: staging
                        downstream is skipped instead of failing obscurely.
    check='unexpected'  fails for every live column the contract doesn't know
                        about (vendor added or renamed something). Use with
                        severity warn.

    When the vendor changes the layout on purpose: update staging, then
    regenerate the contract rows for that table.
-#}
{% test raw_schema_matches_contract(model, check='missing') %}

with contract as (

    select lower(column_name) as column_name
    from {{ ref('raw_schema_contract') }}
    where lower(table_name) = lower('{{ model.identifier }}')

),

live as (

    select lower(column_name) as column_name
    from {{ model.database }}.information_schema.columns
    where table_schema = upper('{{ model.schema }}')
        and table_name = upper('{{ model.identifier }}')

)

{% if check == 'missing' %}
select
    '{{ model.identifier }}' as table_name,
    contract.column_name,
    'missing from raw table' as problem
from contract
where contract.column_name not in (select column_name from live)
{% elif check == 'unexpected' %}
select
    '{{ model.identifier }}' as table_name,
    live.column_name,
    'not in raw_schema_contract' as problem
from live
where live.column_name not in (select column_name from contract)
{% else %}
{{ exceptions.raise_compiler_error("raw_schema_matches_contract: check must be 'missing' or 'unexpected'") }}
{% endif %}

{% endtest %}
