{#- The raw Ergast/Kaggle load keeps nulls as the literal two-character text \N
    (and a few qualifying times as empty strings). Normalise both to SQL null. -#}
{% macro clean_text(column) -%}
    nullif(nullif(trim({{ column }}), chr(92) || 'N'), '')
{%- endmacro %}

{#- Lower-case letters only, accents folded, for fuzzy name comparison across feeds
    ('Hülkenberg' and 'HULKENBERG' both become 'hulkenberg'). -#}
{% macro normalize_name(column) -%}
    regexp_replace(
        translate(lower({{ column }}),
            'áàâäãåāéèêëēíìîïīóòôöõøōúùûüūýÿçćčñšžđł',
            'aaaaaaaeeeeeiiiiiooooooouuuuuyycccnszdl'),
        '[^a-z]', '')
{%- endmacro %}
