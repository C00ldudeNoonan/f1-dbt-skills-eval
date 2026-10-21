{#- Fails when any value in a raw text column does not match the expected format. Raw
    null markers (`\N`, empty string, real NULL) are allowed unless `allow_null` is false.
    Catches vendor format changes (date formats, time formats, numeric text) before they
    turn into silent nulls or wrong numbers downstream. -#}
{% test matches_regex(model, column_name, regex, allow_null=true) %}

select {{ column_name }} as bad_value, count(*) as n_rows
from {{ model }}
where {{ column_name }} is not null
    and not regexp_like(trim({{ column_name }}), '{{ regex }}')
    {% if allow_null %}
    and trim({{ column_name }}) not in ('\\N', '')
    {% endif %}
group by 1

{% endtest %}
