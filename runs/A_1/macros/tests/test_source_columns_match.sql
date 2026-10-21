{#
  Schema contract for a raw source table: compares the live columns in
  information_schema with the columns we expect the vendor to deliver.

  check='breaking'  -> returns expected columns that are missing, or whose type
                       changed. Run at severity error: staging would break or
                       silently change meaning.
  check='additive'  -> returns columns the vendor added that we don't know
                       about. Run at severity warn: harmless, but worth a look
                       (often half of a rename).

  Each failing row names the column and what changed, so a vendor migration
  shows up as e.g. "POSITIONORDER | missing" instead of an
  "invalid identifier" error deep inside a staging model.
#}

{% test source_columns_match(model, expected_columns, check='breaking', expected_data_type='TEXT') %}

with expected as (
    {% for column in expected_columns %}
    select '{{ column | upper }}' as column_name, '{{ expected_data_type | upper }}' as expected_data_type
    {% if not loop.last %}union all{% endif %}
    {% endfor %}
),

actual as (
    select column_name, data_type
    from {{ model.database }}.information_schema.columns
    where table_schema = '{{ model.schema | upper }}'
      and table_name = '{{ model.identifier | upper }}'
)

{% if check == 'breaking' %}
select
    expected.column_name,
    iff(actual.column_name is null, 'missing', 'type changed to ' || actual.data_type) as problem
from expected
left join actual
    on expected.column_name = actual.column_name
where actual.column_name is null
   or actual.data_type <> expected.expected_data_type
{% elif check == 'additive' %}
select
    actual.column_name,
    'unexpected new column (' || actual.data_type || ')' as problem
from actual
left join expected
    on actual.column_name = expected.column_name
where expected.column_name is null
{% else %}
    {{ exceptions.raise_compiler_error("source_columns_match: check must be 'breaking' or 'additive', got '" ~ check ~ "'") }}
{% endif %}

{% endtest %}
