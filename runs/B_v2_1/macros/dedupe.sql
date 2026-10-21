{#-
  Drop re-delivered rows: keep one row per natural key. The vendor has resent
  rows with a new surrogate id or trailing whitespace (2026-10-21: Ferrari in
  CONSTRUCTORS, race 1142 in DRIVER_STANDINGS), which would fan out every join.
  Re-deliveries with identical values are safe to collapse; the source test
  no_conflicting_duplicates fails the build if the copies disagree, and
  audit_source_duplicates shows how many were dropped.
-#}
{% macro dedupe(partition_by, order_by) -%}
qualify row_number() over (partition by {{ partition_by }} order by {{ order_by }}) = 1
{%- endmacro %}
