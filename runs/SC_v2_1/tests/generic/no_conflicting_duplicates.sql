{#- Fails when rows sharing a key disagree on any other column (ignoring `ignore_columns`
    such as surrogate ids, and surrounding whitespace). Identical re-sent rows are healed
    by staging; conflicting ones need a human, so they stop the build before any model
    reads the table. -#}
{% test no_conflicting_duplicates(model, key_columns, ignore_columns=[]) %}

{%- set skip = (key_columns + ignore_columns) | map('lower') | list -%}
{%- set cols = [] -%}
{%- if execute -%}
    {%- for name in run_query('describe table ' ~ model).columns[0].values() -%}
        {%- if (name | lower) not in skip -%}{%- do cols.append(name) -%}{%- endif -%}
    {%- endfor -%}
{%- endif -%}

select {{ key_columns | join(', ') }}, count(distinct hash({% if cols %}{% for c in cols %}trim({{ c }}){% if not loop.last %}, {% endif %}{% endfor %}{% else %}1{% endif %})) as n_versions
from {{ model }}
group by {{ key_columns | join(', ') }}
having count(distinct hash({% if cols %}{% for c in cols %}trim({{ c }}){% if not loop.last %}, {% endif %}{% endfor %}{% else %}1{% endif %})) > 1

{% endtest %}
