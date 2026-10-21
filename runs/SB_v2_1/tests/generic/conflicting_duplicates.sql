{% test conflicting_duplicates(model, key_columns, compare_columns) %}
{#- Staging removes duplicate rows per key. That is only safe when the duplicates are identical, so this
    test fails (error) when the same key appears with different values (ignoring surrounding whitespace, which staging trims), i.e. we would be choosing
    between two conflicting versions of a fact. -#}
select {{ key_columns | join(', ') }}, count(*) as copies
from {{ model }}
group by {{ key_columns | join(', ') }}
having count(*) > 1
   and count(distinct hash({% for c in compare_columns %}trim({{ c }}){{ ', ' if not loop.last }}{% endfor %})) > 1
{% endtest %}
