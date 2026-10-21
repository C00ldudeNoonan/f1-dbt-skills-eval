{#- Warns about leading/trailing whitespace in raw text columns (staging trims them, but
    untrimmed keys and names are how duplicate-looking entities appear). -#}
{% test no_untrimmed_values(model, columns) %}

{{ config(severity='warn') }}

{% for c in columns %}
select '{{ c }}' as column_name, count(*) as n_rows
from {{ model }}
where {{ c }} <> trim({{ c }})
having count(*) > 0
{% if not loop.last %}union all{% endif %}
{% endfor %}

{% endtest %}
