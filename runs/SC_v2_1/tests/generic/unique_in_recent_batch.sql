{#- Uniqueness check that only reads the most recent day of `loaded_at` (so routine runs do
    not rescan a huge table). Set var full_telemetry_tests: true to check the whole table. -#}
{% test unique_in_recent_batch(model, columns) %}

select {{ columns | join(', ') }}, count(*) as n_records
from {{ model }}
{% if not var('full_telemetry_tests') %}
where loaded_at >= dateadd(day, -1, (select max(loaded_at) from {{ model }}))
{% endif %}
group by {{ columns | join(', ') }}
having count(*) > 1

{% endtest %}
