{#
    Normalizes a name or place for matching across feeds: lower case, accents folded to
    plain letters, and everything except a-z removed. "Montmeló" and "Montmelo" both become
    "montmelo", and "de Vries" and "DE VRIES" both become "devries".
#}
{% macro normalize_text(column_name) -%}
    regexp_replace(
        translate(lower({{ column_name }}), 'áàâäãåéèêëíìîïóòôöõúùûüçñýÿ', 'aaaaaaeeeeiiiiooooouuuucnyy'),
        '[^a-z]', ''
    )
{%- endmacro %}
