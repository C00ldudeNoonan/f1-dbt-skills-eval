{#- Grain guard: a fact must have exactly as many rows as the model it is built from (catches join fan-out and drops). -#}
{% test row_count_equals(model, compare_model) %}
select model_rows, compare_rows
from (
    select
        (select count(*) from {{ model }}) as model_rows,
        (select count(*) from {{ compare_model }}) as compare_rows
)
where model_rows <> compare_rows
{% endtest %}
