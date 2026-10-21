{#
    Folds common accented letters to plain ASCII so names match across feeds (Hülkenberg matches HULKENBERG).
    The two character lists are the same length and map position by position.
#}
{% macro fold_accents(column_name) -%}
    translate({{ column_name }}, 'ÁÀÂÄÃÉÈÊËÍÌÎÏÓÒÔÖÕÚÙÛÜÑÇáàâäãéèêëíìîïóòôöõúùûüñç', 'AAAAAEEEEIIIIOOOOOUUUUNCaaaaaeeeeiiiiooooouuuunc')
{%- endmacro %}
