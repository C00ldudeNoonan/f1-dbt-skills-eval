{% test matches_format(model, column_name, pattern) %}
{#- Fails for any non-missing value that does not match the format our staging parsing expects.
    Missing = null, empty or the vendor's \N sentinel. -#}
select {{ column_name }} as offending_value, count(*) as n
from {{ model }}
where {{ column_name }} is not null
  and trim({{ column_name }}) not in ('', $$\N$$)
  and not regexp_like(trim({{ column_name }}), '{{ pattern }}')
group by 1
{% endtest %}
