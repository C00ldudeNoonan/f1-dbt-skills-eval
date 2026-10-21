{#
  Returns the races an incremental telemetry model must (re)build: every race
  with rows in `source_relation` loaded after the target's high-water mark,
  minus a lookback window (var `telemetry_lookback_minutes`, default 120).
  The lookback covers loader commit lag, so rows that land slightly out of
  order are still picked up. Reprocessing a race is idempotent, so the overlap
  is safe.

  The two steps run as separate queries and are inlined as literals. The
  high-water mark comes from max() over the target, which Snowflake answers
  from metadata. The race lookup then filters the source on a constant
  timestamp, which lets Snowflake prune micro-partitions. A scalar subquery
  would not guarantee pruning.
#}
{% macro telemetry_races_to_process(target_relation, target_loaded_at, source_relation, source_loaded_at, source_race_column) %}
    {% if not execute %}
        {{ return([]) }}
    {% endif %}

    {% set lookback_minutes = var('telemetry_lookback_minutes', 120) %}

    {% set watermark_query %}
        select to_varchar(
            dateadd(minute, -{{ lookback_minutes }}, max({{ target_loaded_at }})),
            'YYYY-MM-DD HH24:MI:SS.FF9'
        )
        from {{ target_relation }}
    {% endset %}
    {% set watermark = run_query(watermark_query).columns[0].values()[0] %}

    {% set races_query %}
        select distinct {{ source_race_column }}
        from {{ source_relation }}
        {% if watermark is not none %}
        where {{ source_loaded_at }} > '{{ watermark }}'::timestamp_ntz
        {% endif %}
        order by 1
    {% endset %}
    {% set races = run_query(races_query).columns[0].values() | list %}
    {{ log(this.identifier ~ ': ' ~ races | length ~ ' race(s) to process since ' ~ watermark, info=True) }}
    {{ return(races) }}
{% endmacro %}


{# SQL predicate restricting `column` to the given races ('false' when there are none). #}
{% macro race_filter(column, races) -%}
    {%- if races | length == 0 -%}
        false
    {%- else -%}
        {{ column }} in ({{ races | join(', ') }})
    {%- endif -%}
{%- endmacro %}
