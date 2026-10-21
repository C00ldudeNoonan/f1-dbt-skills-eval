{#- Guards the *format* of raw text columns. The vendor delivers everything as text, so a silent
    change (date order, time layout, null spelling) would otherwise parse to wrong numbers or nulls.
    `pattern` must match the whole value; with nullable=true the `\N` marker and blanks also pass. -#}
{% test source_value_format(model, column_name, pattern, nullable=false) %}

select
    {{ column_name }} as unexpected_value,
    count(*) as n_rows
from {{ model }}
where not regexp_like(trim(coalesce({{ column_name }}, '')), '{{ pattern }}')
    {% if nullable %}
    and trim(coalesce({{ column_name }}, '')) not in (chr(92) || 'N', '')
    {% endif %}
group by 1

{% endtest %}
