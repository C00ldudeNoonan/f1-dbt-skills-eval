{#- Run at the start of every run/build. Compares each source table's declared columns (the ones our
    staging models read) with what the warehouse actually has, and stops with ONE report listing every
    missing table or column, so a vendor rename is obvious instead of a pile of SQL errors.
    Extra, undeclared columns cannot break us and are ignored. One metadata query per source schema. -#}
{% macro check_source_schema() %}
  {% if execute %}
    {% set problems = [] %}
    {% set by_schema = {} %}
    {% for node in graph.sources.values() if node.columns | length > 0 %}
      {% do by_schema.setdefault(node.database ~ '.' ~ node.schema, []).append(node) %}
    {% endfor %}
    {% for key, nodes in by_schema.items() %}
      {% set query %}
        select upper(table_name), upper(column_name)
        from {{ nodes[0].database }}.information_schema.columns
        where table_schema ilike '{{ nodes[0].schema }}'
      {% endset %}
      {% set actual = {} %}
      {% for row in run_query(query).rows %}
        {% do actual.setdefault(row[0], []).append(row[1]) %}
      {% endfor %}
      {% for node in nodes %}
        {% set table = node.identifier | upper %}
        {% set label = nodes[0].schema ~ '.' ~ node.identifier ~ ' (source ' ~ node.source_name ~ '.' ~ node.name ~ ')' %}
        {% if table not in actual %}
          {% do problems.append('TABLE MISSING: ' ~ label) %}
        {% else %}
          {% for col in node.columns.keys() if (col | upper) not in actual[table] %}
            {% do problems.append('COLUMN MISSING: ' ~ label ~ ' no longer has ' ~ (col | upper)) %}
          {% endfor %}
        {% endif %}
      {% endfor %}
    {% endfor %}
    {% if problems | length > 0 %}
      {{ exceptions.raise_compiler_error('VENDOR SCHEMA CHANGE DETECTED. Fix the source mapping (source identifier / staging column names) before running:\n  - ' ~ problems | join('\n  - ')) }}
    {% endif %}
  {% endif %}
{% endmacro %}
