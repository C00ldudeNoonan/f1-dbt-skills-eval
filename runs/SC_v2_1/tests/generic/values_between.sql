{#- Fails when a numeric-as-text value falls outside a plausible range. Raw null markers
    (`\N`, blank) are ignored. Catches unit changes and corrupted numbers. -#}
{% test values_between(model, column_name, min_value, max_value) %}

select {{ column_name }} as bad_value, count(*) as n_rows
from {{ model }}
where try_to_double({{ column_name }}) is not null
    and (try_to_double({{ column_name }}) < {{ min_value }} or try_to_double({{ column_name }}) > {{ max_value }})
group by 1

{% endtest %}
