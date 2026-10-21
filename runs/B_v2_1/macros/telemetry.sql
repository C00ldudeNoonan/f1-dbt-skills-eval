{#-
  Helpers for the incremental telemetry models. They run small metadata
  queries at execution time so the main SQL can use literal values, which
  Snowflake can use for micro-partition pruning (subqueries can't be pruned
  statically).
-#}

{#- Max of a column in an existing relation, as a SQL literal ('...'::timestamp_ntz), or none. -#}
{% macro telemetry_watermark(relation, column) %}
    {% if not execute %}{{ return(none) }}{% endif %}
    {% set result = run_query("select to_varchar(max(" ~ column ~ "), 'YYYY-MM-DD HH24:MI:SS.FF9') from " ~ relation) %}
    {% set value = result.columns[0].values()[0] %}
    {{ return(("'" ~ value ~ "'::timestamp_ntz") if value else none) }}
{% endmacro %}

{#- Distinct race_ids matching a filter, as a SQL list literal like (1120, 1121), or (null) when none. -#}
{% macro telemetry_race_list(relation, race_column, where) %}
    {% if not execute %}{{ return('(null)') }}{% endif %}
    {% set result = run_query("select distinct " ~ race_column ~ " from " ~ relation ~ " where " ~ where ~ " order by 1") %}
    {% set races = result.columns[0].values() | map('int') | map('string') | list %}
    {{ return('(' ~ (races | join(', ') if races else 'null') ~ ')') }}
{% endmacro %}
