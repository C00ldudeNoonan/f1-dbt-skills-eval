{#- Fails with one row per expected column missing from the source table, so an upstream
    rename/drop shows up as "source X is missing column Y" instead of a downstream SQL error.
    Source tests run before the staging models that read the source. -#}
{% test source_has_columns(model, columns) %}
{%- set actual = adapter.get_columns_in_relation(model) | map(attribute='name') | map('lower') | list -%}
{%- set missing = [] -%}
{%- for c in columns -%}
    {%- if c | lower not in actual -%}{%- do missing.append(c) -%}{%- endif -%}
{%- endfor -%}
{% if missing | length == 0 %}
select 'ok' as missing_column where false
{% else %}
{% for c in missing %}
select '{{ model.identifier }}: missing expected column {{ c }}' as missing_column
{% if not loop.last %}union all{% endif %}
{% endfor %}
{% endif %}
{% endtest %}
