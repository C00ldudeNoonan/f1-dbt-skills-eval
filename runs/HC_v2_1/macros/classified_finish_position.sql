{#
    The classified finishing place for a result. POSITION is null for non-finishers, but two lapped
    finishers in 2005 have POSITION null and a numeric POSITIONTEXT, so the text is used when it is numeric.
    Letter codes (R, D, W, F, N, E) leave the result unclassified.
#}
{% macro classified_finish_position(position_column, position_text_column) -%}
    coalesce(
        {{ position_column }},
        case
            when regexp_like({{ position_text_column }}, '^[0-9]+$')
                then {{ position_text_column }}::integer
        end
    )
{%- endmacro %}
