{#-
  Re-delivery checks for vendor tables, keyed on each table's natural key.
  Values are compared after trimming and null-marker cleanup, so a copy that
  differs only by whitespace counts as the same row.
-#}

{#- Fails when one natural key arrives with different values: we can't know which copy is right. -#}
{% test no_conflicting_duplicates(model, key_columns, compare_columns) %}
select
    {% for c in key_columns %}{{ clean_text(c) }} as {{ c }}, {% endfor %}
    count(*) as copies,
    count(distinct hash({% for c in compare_columns %}{{ clean_text(c) }}{{ ", " if not loop.last }}{% endfor %})) as distinct_versions
from {{ model }}
group by {% for c in key_columns %}{{ clean_text(c) }}{{ ", " if not loop.last }}{% endfor %}
having count(distinct hash({% for c in compare_columns %}{{ clean_text(c) }}{{ ", " if not loop.last }}{% endfor %})) > 1
{% endtest %}

{#- One row per natural key that was delivered more than once (use with severity: warn). -#}
{% test no_redelivered_rows(model, key_columns) %}
select
    {% for c in key_columns %}{{ clean_text(c) }} as {{ c }}, {% endfor %}
    count(*) as copies
from {{ model }}
group by {% for c in key_columns %}{{ clean_text(c) }}{{ ", " if not loop.last }}{% endfor %}
having count(*) > 1
{% endtest %}
