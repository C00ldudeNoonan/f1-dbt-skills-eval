{#- Latest `loaded_at` already in the relation (metadata-only for a min/max aggregate), or
    NULL when empty. Used as the incremental watermark. -#}
{% macro telemetry_watermark(relation, column_name='loaded_at') -%}
    {%- if execute -%}
        {%- set result = run_query('select max(' ~ column_name ~ ') from ' ~ relation) -%}
        {{- result.columns[0].values()[0] -}}
    {%- endif -%}
{%- endmacro %}

{#- Comma-separated race ids that have rows loaded since (watermark - lookback) in `source_relation`.
    Resolved to literals at run time so the main query gets static partition pruning. -#}
{% macro telemetry_affected_races(source_relation, watermark) -%}
    {%- set races = [] -%}
    {%- if execute and watermark -%}
        {%- set result = run_query(
            "select distinct race_id from " ~ source_relation
            ~ " where loaded_at >= dateadd(hour, -" ~ var('telemetry_lookback_hours') ~ ", '" ~ watermark ~ "'::timestamp_ntz)"
        ) -%}
        {%- for v in result.columns[0].values() -%}{%- do races.append(v | string) -%}{%- endfor -%}
    {%- endif -%}
    {{- races | join(', ') if races else '-1' -}}
{%- endmacro %}
