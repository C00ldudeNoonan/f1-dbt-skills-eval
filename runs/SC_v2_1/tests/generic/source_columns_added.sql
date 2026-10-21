{#- Warns when the raw table has columns we have not reviewed (a vendor schema change). -#}
{% test source_columns_added(model, expected_columns) %}

{{ config(severity='warn') }}

{%- set expected = expected_columns | map('upper') | list -%}
{%- set added = [] -%}
{%- if execute -%}
    {%- for name in run_query('describe table ' ~ model).columns[0].values() -%}
        {%- if (name | upper) not in expected -%}{%- do added.append(name) -%}{%- endif -%}
    {%- endfor -%}
{%- endif -%}

select column_name as unexpected_column
from (select null::varchar as column_name) as empty
where false
{% for c in added %}
union all
select '{{ c }}'
{% endfor %}

{% endtest %}
