{#-
  Source format contract. Fails for every non-null value (ignoring the `\N`
  and empty-string null markers) that does not match the expected regex, so a
  vendor format change fails loudly instead of parsing to null or to a wrong
  value. Patterns avoid backslashes: use [.] for a literal dot.
-#}
{% test matches_pattern(model, column_name, pattern) %}
select
    {{ column_name }} as unexpected_value,
    count(*) as n_rows
from {{ model }}
where {{ clean_text(column_name) }} is not null
    and not regexp_like(trim({{ column_name }}), '{{ pattern }}')
group by 1
{% endtest %}
