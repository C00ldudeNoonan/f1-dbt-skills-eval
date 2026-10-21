{#- Rows that share a key. Warn by default: staging de-duplicates these so they cannot
    inflate downstream numbers, but the vendor re-sending rows should be visible every
    run. Use severity='error' for keys staging does not heal. -#}
{% test duplicate_key_rows(model, key_columns, severity='warn') %}

{{ config(severity=severity) }}

select {{ key_columns | join(', ') }}, count(*) as n_rows
from {{ model }}
group by {{ key_columns | join(', ') }}
having count(*) > 1

{% endtest %}
