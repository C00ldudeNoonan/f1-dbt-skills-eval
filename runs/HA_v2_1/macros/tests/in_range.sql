{#
    Fails for every non-null value outside [min_value, max_value]. Catches impossible values
    from a corrupted feed (for example negative points or a 50-hour lap).
#}
{% test in_range(model, column_name, min_value, max_value) %}

select {{ column_name }} as bad_value
from {{ model }}
where {{ column_name }} is not null
    and ({{ column_name }} < {{ min_value }} or {{ column_name }} > {{ max_value }})

{% endtest %}
