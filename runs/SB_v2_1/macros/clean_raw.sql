{#- Raw tables were loaded as text; missing values appear as the literal two characters \N
    (and occasionally as empty strings). Dollar quoting keeps the backslash literal. -#}
{% macro clean_raw(column) -%}
    nullif(nullif(trim({{ column }}), $$\N$$), '')
{%- endmacro %}

{% macro clean_int(column) -%}
    try_to_number({{ clean_raw(column) }})::integer
{%- endmacro %}

{% macro clean_decimal(column, scale=2) -%}
    try_to_decimal({{ clean_raw(column) }}, 12, {{ scale }})
{%- endmacro %}

{#- Parses lap-style times ('m:ss.mmm', minutes may exceed 9, optional 'h:mm:ss.mmm' for red-flag laps)
    into integer milliseconds. -#}
{% macro lap_time_to_ms(column) -%}
    case
        when regexp_like({{ clean_raw(column) }}, '^[0-9]+:[0-9]{2}\\.[0-9]{3}$')
            then regexp_substr({{ clean_raw(column) }}, '^([0-9]+):([0-9]{2})\\.([0-9]{3})$', 1, 1, 'e', 1)::integer * 60000
                + regexp_substr({{ clean_raw(column) }}, '^([0-9]+):([0-9]{2})\\.([0-9]{3})$', 1, 1, 'e', 2)::integer * 1000
                + regexp_substr({{ clean_raw(column) }}, '^([0-9]+):([0-9]{2})\\.([0-9]{3})$', 1, 1, 'e', 3)::integer
        when regexp_like({{ clean_raw(column) }}, '^[0-9]+:[0-9]+:[0-9]{2}\\.[0-9]{3}$')
            then regexp_substr({{ clean_raw(column) }}, '^([0-9]+):([0-9]+):([0-9]{2})\\.([0-9]{3})$', 1, 1, 'e', 1)::integer * 3600000
                + regexp_substr({{ clean_raw(column) }}, '^([0-9]+):([0-9]+):([0-9]{2})\\.([0-9]{3})$', 1, 1, 'e', 2)::integer * 60000
                + regexp_substr({{ clean_raw(column) }}, '^([0-9]+):([0-9]+):([0-9]{2})\\.([0-9]{3})$', 1, 1, 'e', 3)::integer * 1000
                + regexp_substr({{ clean_raw(column) }}, '^([0-9]+):([0-9]+):([0-9]{2})\\.([0-9]{3})$', 1, 1, 'e', 4)::integer
    end
{%- endmacro %}

{#- Race dates arrive as dd/mm/yyyy since the vendor migration (previously yyyy-mm-dd). Both are
    accepted; they cannot be confused because the ISO form starts with a four-digit year. -#}
{% macro clean_date(column) -%}
    coalesce(
        try_to_date({{ clean_raw(column) }}, 'YYYY-MM-DD'),
        try_to_date({{ clean_raw(column) }}, 'DD/MM/YYYY')
    )
{%- endmacro %}

{#- Order- and accent-insensitive person-name key, so 'HULKENBERG Nico' and 'Nico Hülkenberg' compare equal. -#}
{% macro name_key(expr) -%}
    array_to_string(
        array_sort(split(
            trim(regexp_replace(
                regexp_replace(
                    lower(translate({{ expr }},
                        'ÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝàáâãäåçèéêëìíîïñòóôõöùúûüýÿĀāĂăĄąĆćĈĉĊċČčĎďĒēĔĕĖėĘęĚěĜĝĞğĠġĢģĤĥĨĩĪīĬĭĮįİĴĵĶķĹĺĻļĽľĿŀŃńŅņŇňŉŌōŎŏŐőŔŕŖŗŘřŚśŜŝŞşŠšŢţŤťŨũŪūŬŭŮůŰűŲųŴŵŶŷŸŹźŻżŽžſ',
                        'AAAAAACEEEEIIIINOOOOOUUUUYaaaaaaceeeeiiiinooooouuuuyyAaAaAaCcCcCcCcDdEeEeEeEeEeGgGgGgGgHhIiIiIiIiIJjKkLlLlLlLlNnNnNnnOoOoOoRrRrRrSsSsSsSsTtTtUuUuUuUuUuUuWwYyYZzZzZzs')),
                    '[^a-z ]', ''),
                '\\s+', ' ')),
            ' ')),
        ' ')
{%- endmacro %}
