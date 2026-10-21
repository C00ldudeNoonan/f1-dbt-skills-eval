{{ config(severity='warn') }}
{#
    Text values in the raw feed with leading or trailing spaces. The staging models trim text,
    so outputs are unaffected, but a copy with extra spaces is how exact duplicates appear
    (see dedupe_raw). Warns so the vendor issue stays visible.
#}
{% set contract = raw_contract() %}
{% set keys = raw_keys() %}
{% set parts = [] %}
{% for table_name, columns in contract.items() if keys[table_name].get('scan', true) %}
    {% for column_name in columns %}
        {% do parts.append(
            "select '" ~ table_name ~ "." ~ column_name ~ "' as table_column, count(*) as untrimmed_values "
            ~ "from " ~ source('f1_raw', table_name) ~ " "
            ~ "where " ~ column_name ~ " <> trim(" ~ column_name ~ ") "
            ~ "having count(*) > 0"
        ) %}
    {% endfor %}
{% endfor %}
{{ parts | join(' union all ') }}
