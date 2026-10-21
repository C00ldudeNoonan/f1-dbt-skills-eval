{#-
    Hash of a raw row's cleaned content (trimmed, \N and empty strings as null),
    i.e. the row as staging sees it. Two raw rows with the same hash are
    interchangeable copies even if their bytes differ (October 2026: a second
    Ferrari CONSTRUCTORS row differed only by a trailing space).
    ignore_columns: surrogate ids to leave out.
-#}
{% macro raw_row_hash(relation, ignore_columns=[]) -%}
    {%- set ignore = ignore_columns | map('lower') | list -%}
    {%- set columns = [] -%}
    {%- for column in adapter.get_columns_in_relation(relation) -%}
        {%- if column.name | lower not in ignore -%}
            {%- do columns.append(clean_text(column.name)) -%}
        {%- endif -%}
    {%- endfor -%}
    hash({{ columns | join(', ') }})
{%- endmacro %}
