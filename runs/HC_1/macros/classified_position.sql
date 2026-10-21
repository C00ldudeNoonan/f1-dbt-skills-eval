{#- Classified finishing position. `position` is null for unclassified entries (R, D, E, W, F, N).
    Two lapped finishers in the 2005 Australian Grand Prix have a null `position` but a digit-only
    `positiontext`, so fall back to the text. Digits are checked explicitly because
    try_to_number('E') returns 0 in Snowflake. -#}
{% macro classified_position(position_column, position_text_column) %}
    coalesce(
        try_to_number({{ null_if_sentinel(position_column) }}),
        iff(regexp_like({{ null_if_sentinel(position_text_column) }}, '[0-9]+'), try_to_number({{ null_if_sentinel(position_text_column) }}), null)
    )
{% endmacro %}
