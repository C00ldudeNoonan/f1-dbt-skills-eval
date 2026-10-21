{#
    Generic test: fails for each combination of columns that appears more than once.
    Use it as the grain check for models without a single-column key.
#}
{% test unique_combination_of_columns(model, combination_of_columns) %}

select
    {{ combination_of_columns | join(', ') }},
    count(*) as duplicate_rows
from {{ model }}
group by {{ combination_of_columns | join(', ') }}
having count(*) > 1

{% endtest %}
