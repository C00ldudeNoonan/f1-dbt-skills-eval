{#- Fails when a column we depend on is missing from the raw table (or the whole table is
    gone / renamed). Returns one row per missing column. Uses a live DESCRIBE (fast;
    information_schema is very slow here and adapter.get_columns_in_relation can return a stale cached schema). -#}
{% test source_columns_missing(model, expected_columns) %}

{%- set actual = [] -%}
{%- if execute -%}
    {%- for name in run_query('describe table ' ~ model).columns[0].values() -%}
        {%- do actual.append(name | upper) -%}
    {%- endfor -%}
{%- endif -%}
{%- set missing = [] -%}
{%- for c in expected_columns -%}
    {%- if (c | upper) not in actual -%}{%- do missing.append(c) -%}{%- endif -%}
{%- endfor -%}

select column_name as missing_column
from (select null::varchar as column_name) as empty
where false
{% for c in missing %}
union all
select '{{ c }}'
{% endfor %}

{% endtest %}
