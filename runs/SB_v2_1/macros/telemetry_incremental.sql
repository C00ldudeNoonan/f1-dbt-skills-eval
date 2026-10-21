{#- Incremental window for telemetry models.
    High-water mark = max(<column>) already in the target, minus a small lookback to tolerate loader clock skew
    and in-flight loads (merging makes re-reading idempotent). Filtering on ingestion time (`loaded_at`) rather
    than event time is what lets late samples for old races be picked up. -#}
{% macro telemetry_cutoff(column='loaded_at') %}
    {%- set cutoff = none -%}
    {%- if execute and is_incremental() -%}
        {%- set wm = run_query('select max(' ~ column ~ ') from ' ~ this).columns[0].values()[0] -%}
        {%- if wm is not none -%}
            {%- set cutoff = "dateadd(minute, -" ~ var('telemetry_lookback_minutes', 15) ~ ", '" ~ wm ~ "'::timestamp_ntz)" -%}
        {%- endif -%}
    {%- endif -%}
    {{- return(cutoff) -}}
{% endmacro %}

{#- Distinct values of a column on rows at/after the cutoff, as a list; used to prune the merge target. -#}
{% macro telemetry_affected(relation, column, cutoff, filter_column='loaded_at') %}
    {%- set result = [] -%}
    {%- if execute and cutoff -%}
        {%- set rows = run_query('select distinct ' ~ column ~ ' from ' ~ relation ~ ' where ' ~ filter_column ~ ' >= ' ~ cutoff) -%}
        {%- for row in rows.rows -%}
            {%- do result.append(row[0] | int) -%}
        {%- endfor -%}
    {%- endif -%}
    {{- return(result) -}}
{% endmacro %}
