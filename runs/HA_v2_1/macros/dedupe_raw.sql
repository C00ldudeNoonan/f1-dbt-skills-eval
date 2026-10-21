{#
    Removes exact duplicate rows from a raw table before staging reads it.

    The feed occasionally re-sends a row with a different surrogate id but identical content
    (for example constructor 6 appeared twice, and race 1142 standings appeared with ids offset
    by 100000). Rows are identical except for id_column, so keep the lowest id and drop the rest.

    Text is compared after trim(): the feed sometimes adds a trailing space to a copy
    (for example 'Ferrari ' next to 'Ferrari'). Rows with the same natural key but different
    content are NOT removed here. The pre-build
    check (assert_raw_contract) fails the run on those, before any model builds.

    Pass id_column as none for tables without a surrogate id (all columns are compared).
#}
{% macro dedupe_raw(source_relation, id_column=none) -%}
    {% if execute %}
        {% set names = adapter.get_columns_in_relation(source_relation) | map(attribute='name') | list %}
        {% set content = names | reject('equalto', id_column) | list if id_column else names %}
        {% set order_by = id_column if id_column else names[0] %}
        select * exclude (dedupe_rn)
        from (
            select
                *,
                row_number() over (partition by {% for c in content %}trim({{ c }}){{ ', ' if not loop.last }}{% endfor %} order by {{ order_by }}) as dedupe_rn
            from {{ source_relation }}
        )
        where dedupe_rn = 1
    {% else %}
        select * from {{ source_relation }}
    {% endif %}
{%- endmacro %}
