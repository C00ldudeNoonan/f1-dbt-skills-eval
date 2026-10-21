{#
    Fails for every combination of columns that appears more than once.
#}
{% test unique_together(model, columns) %}

select {{ columns | join(', ') }}, count(*) as row_count
from {{ model }}
group by {{ columns | join(', ') }}
having count(*) > 1

{% endtest %}
