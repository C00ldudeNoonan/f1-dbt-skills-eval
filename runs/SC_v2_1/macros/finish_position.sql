{#- Classified finishing position. Raw POSITION is null for retirements, DSQs etc. but
    also for a few lapped finishers whose classification only survives in POSITIONTEXT. -#}
{% macro finish_position(position, positiontext) -%}
    coalesce(
        try_to_number({{ clean_raw(position) }})::integer,
        case when regexp_like({{ positiontext }}, '^[0-9]+$') then {{ positiontext }}::integer end
    )
{%- endmacro %}
