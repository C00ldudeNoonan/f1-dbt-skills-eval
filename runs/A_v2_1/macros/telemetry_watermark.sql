{#-
    High-water mark for an incremental telemetry model: the latest raw
    loaded_at already incorporated into `relation` (column `watermark_column`),
    minus var('telemetry_lookback_hours') so loads that commit out of order are
    re-read. Re-reading is harmless: the models merge on their natural keys.
    Reading max() of one column uses table metadata/min-max pruning, not a scan.
-#}
{% macro telemetry_watermark(relation, watermark_column) -%}
    (
        select dateadd(hour, -{{ var('telemetry_lookback_hours') }}, coalesce(max({{ watermark_column }}), '1900-01-01'::timestamp_ntz))
        from {{ relation }}
    )
{%- endmacro %}
