{#
    POSITIONTEXT holds the classification for every entry: a finishing
    position for classified cars (1, 2, 3...) and a status letter for the rest
    (R = retired, D = disqualified, E = excluded, W = withdrew, F = failed to
    qualify/mechanical, N = not classified). Returns the integer position when
    the text is numeric, otherwise NULL.
#}
{% macro position_text_to_int(column_name) -%}
    case
        when regexp_like({{ column_name }}, '^[0-9]+$') then try_cast({{ column_name }} as integer)
    end
{%- endmacro %}
