{% test duplicate_keys(model, key_columns) %}
{#- Visibility only (used at warn severity): staging removes duplicate keys, this tells you the vendor sent some. -#}
select {{ key_columns | join(', ') }}, count(*) as copies
from {{ model }}
group by {{ key_columns | join(', ') }}
having count(*) > 1
{% endtest %}
