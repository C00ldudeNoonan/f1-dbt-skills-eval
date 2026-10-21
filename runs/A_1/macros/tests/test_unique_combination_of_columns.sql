{#
  Grain test: the combination of the given columns is unique.
  (Kept in-project rather than pulling in dbt_utils for a single test.)
#}

{% test unique_combination_of_columns(model, combination_of_columns) %}

select
    {{ combination_of_columns | join(', ') }},
    count(*) as n_records
from {{ model }}
group by {{ combination_of_columns | join(', ') }}
having count(*) > 1

{% endtest %}
