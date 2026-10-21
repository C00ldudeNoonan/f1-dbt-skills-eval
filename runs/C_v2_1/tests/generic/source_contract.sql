{#
  Vendor-contract tests for the raw F1 source. They run before anything is
  built from a source table, so when the vendor renames, drops or reformats
  something, the build stops at the source with a precise failure instead of
  silently producing different numbers downstream.
#}

{#
  Every expected column must exist (mode='missing', run as an error), and
  columns we don't know about are reported (mode='unexpected', run as a
  warning, since new columns are harmless until we decide to use them).
  A missing table shows up as every column missing.
#}
{% test source_columns_match(model, expected_columns, mode='missing') %}

with actual as (
    select lower(column_name) as column_name
    from {{ model.database }}.information_schema.columns
    where table_schema = upper('{{ model.schema }}')
        and table_name = upper('{{ model.identifier }}')
),

expected as (
    {% for column in expected_columns %}
    select '{{ column | lower }}' as column_name
    {% if not loop.last %}union all{% endif %}
    {% endfor %}
)

{% if mode == 'missing' %}
select
    expected.column_name,
    'expected column is missing from {{ model.identifier }} (renamed, dropped, or table missing?)' as problem
from expected
left join actual
    on expected.column_name = actual.column_name
where actual.column_name is null
{% else %}
select
    actual.column_name,
    'new column in {{ model.identifier }} that the project does not know about' as problem
from actual
left join expected
    on actual.column_name = expected.column_name
where expected.column_name is null
{% endif %}

{% endtest %}


{#
  Every value must match the agreed text format. Null tokens (\N, empty
  string, whitespace) are allowed only when nullable=true. Returns each
  offending value with its count.
#}
{#
  vendor_b_timestamp allows a '\N' time part (matched as '.N' to avoid
  escaping a backslash through Jinja, SQL and regex).
#}
{% test matches_format(model, column_name, format, nullable=false) %}

{%- set patterns = {
    'integer': '^-?[0-9]+$',
    'decimal': '^-?[0-9]+([.][0-9]+)?$',
    'iso_date': '^[0-9]{4}-[0-9]{2}-[0-9]{2}$',
    'dmy_date': '^[0-9]{2}/[0-9]{2}/[0-9]{4}$',
    'clock_time': '^[0-9]{2}:[0-9]{2}:[0-9]{2}$',
    'lap_time': '^([0-9]+:){0,2}[0-9]{1,2}[.][0-9]{3}$',
    'classification': '^([0-9]+|R|D|E|W|F|N)$',
    'standings_position': '^([0-9]+|D|E)$',
    'driver_code': '^[A-Z]{3}$',
    'vendor_b_full_name': '^[A-Z][A-Z \'\'-]* [A-Z][a-z].*$',
    'vendor_b_timestamp': '^[0-9]{4}-[0-9]{2}-[0-9]{2}T([0-9]{2}:[0-9]{2}:[0-9]{2}|.N)Z$',
    'vendor_b_position': '^([0-9]+|DNF|DSQ)$',
    'text': '.+'
} -%}
{%- if format not in patterns -%}
    {{ exceptions.raise_compiler_error("matches_format: unknown format '" ~ format ~ "'. Known: " ~ patterns.keys() | list | join(', ')) }}
{%- endif -%}

with values_checked as (
    select
        {{ column_name }} as raw_value,
        {{ column_name }} is null
            or trim({{ column_name }}) = ''
            or {{ column_name }} = '\\N' as is_null_token
    from {{ model }}
)

select
    raw_value,
    count(*) as row_count
from values_checked
where
    {% if nullable %}
    not is_null_token and
    {% endif %}
    (is_null_token or not regexp_like(raw_value, '{{ patterns[format] }}'))
group by raw_value

{% endtest %}


{#
  Duplicates on a natural key are tolerated only when every copy carries the
  same content, so staging can safely keep one. Values are compared after the
  same cleaning staging applies (trim; \N and empty string count as null).
  `ignore_columns` are vendor surrogate ids that differ between copies. Any key
  whose copies disagree is returned, because there's no safe row to keep.
#}
{% test duplicates_are_identical(model, key_columns, ignore_columns=[]) %}

{%- set skip = (key_columns + ignore_columns) | map('lower') | list -%}
{%- set compare_columns = [] -%}
{%- for column in adapter.get_columns_in_relation(model) -%}
    {%- if column.name | lower not in skip -%}
        {%- do compare_columns.append(column.name) -%}
    {%- endif -%}
{%- endfor -%}

with duplicate_keys as (
    select {{ key_columns | join(', ') }}
    from {{ model }}
    group by {{ key_columns | join(', ') }}
    having count(*) > 1
),

copies as (
    select
        {% for key in key_columns %}source_rows.{{ key }}, {% endfor %}
        hash(
            {% for column in compare_columns %}
            nullif(nullif(trim(source_rows.{{ column }}), '\\N'), ''){{ "," if not loop.last }}
            {% endfor %}
        ) as content_hash
    from {{ model }} as source_rows
    inner join duplicate_keys
        on {% for key in key_columns %}source_rows.{{ key }} = duplicate_keys.{{ key }}{{ " and " if not loop.last }}{% endfor %}
)

select
    {{ key_columns | join(', ') }},
    count(*) as copies,
    count(distinct content_hash) as distinct_versions
from copies
group by {{ key_columns | join(', ') }}
having count(distinct content_hash) > 1

{% endtest %}
