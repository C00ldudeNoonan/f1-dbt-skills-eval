{#
    The vendor feed contract. Every table and column this project reads from
    ANALYTICS_DEV.F1_RAW_HA_V2_1, and nothing else.

    If the vendor renames, adds, or drops a table or column, assert_raw_contract (run as an
    on-run-start hook) stops the run with the exact list of differences, before any model
    builds. Update this macro only after the staging models have been updated for the change.

    Column formats are checked separately by the raw_format test in models/staging/f1/_f1__sources.yml.
#}
{% macro raw_contract() %}
    {% set contract = {
        'CIRCUITS': ['CIRCUITID', 'CIRCUITREF', 'NAME', 'LOCATION', 'COUNTRY', 'LAT', 'LNG', 'ALT', 'URL'],
        'CONSTRUCTORS': ['CONSTRUCTORID', 'CONSTRUCTORREF', 'NAME', 'NATIONALITY', 'URL'],
        'CONSTRUCTOR_RESULTS': ['CONSTRUCTORRESULTSID', 'RACEID', 'CONSTRUCTORID', 'POINTS', 'STATUS'],
        'CONSTRUCTOR_STANDINGS': ['CONSTRUCTORSTANDINGSID', 'RACEID', 'CONSTRUCTORID', 'POINTS', 'POSITION', 'POSITIONTEXT', 'WINS'],
        'DRIVERS': ['DRIVERID', 'DRIVERREF', 'NUMBER', 'CODE', 'FORENAME', 'SURNAME', 'DOB', 'NATIONALITY', 'URL'],
        'DRIVER_STANDINGS': ['DRIVERSTANDINGSID', 'RACEID', 'DRIVERID', 'POINTS', 'POSITION', 'POSITIONTEXT', 'WINS'],
        'LAP_TIMING': ['RACEID', 'DRIVERID', 'LAP', 'POSITION', 'TIME', 'MILLISECONDS'],
        'PIT_STOPS': ['RACEID', 'DRIVERID', 'STOP', 'LAP', 'TIME', 'MILLISECONDS'],
        'QUALIFYING': ['QUALIFYID', 'RACEID', 'DRIVERID', 'CONSTRUCTORID', 'NUMBER', 'POSITION', 'Q1', 'Q2', 'Q3'],
        'RACES': ['RACEID', 'YEAR', 'ROUND', 'CIRCUITID', 'NAME', 'DATE', 'TIME', 'URL', 'FP1_DATE', 'FP1_TIME', 'FP2_DATE', 'FP2_TIME', 'FP3_DATE', 'FP3_TIME', 'QUALI_DATE', 'QUALI_TIME', 'SPRINT_DATE', 'SPRINT_TIME'],
        'RESULTS': ['RESULTID', 'RACEID', 'DRIVERID', 'CONSTRUCTORID', 'NUMBER', 'GRID', 'POSITION', 'POSITIONTEXT', 'POSITION_ORDER', 'POINTS', 'LAPS', 'TIME', 'MILLISECONDS', 'FASTESTLAP', 'RANK', 'FASTESTLAPTIME', 'FASTESTLAPSPEED', 'STATUSID'],
        'SEASONS': ['YEAR', 'URL'],
        'SPRINT_RESULTS': ['RESULTID', 'RACEID', 'DRIVERID', 'CONSTRUCTORID', 'NUMBER', 'GRID', 'POSITION', 'POSITIONTEXT', 'POSITION_ORDER', 'POINTS', 'LAPS', 'TIME', 'MILLISECONDS', 'FASTESTLAP', 'FASTESTLAPTIME', 'STATUSID'],
        'STATUS': ['STATUSID', 'STATUS'],
        'VB_DRIVERS': ['DRIVER_KEY', 'FULL_NAME', 'ABBREVIATION', 'RACING_NUMBER'],
        'VB_SESSIONS': ['SESSION_KEY', 'SESSION_TYPE', 'MEETING_NAME', 'YEAR', 'DATE_START'],
        'VB_RESULTS': ['SESSION_KEY', 'DRIVER_KEY', 'TEAM_NAME', 'GRID_POSITION', 'POSITION', 'POINTS'],
        'CAR_TELEMETRY': ['RACEID', 'DRIVERID', 'LAP', 'SAMPLE_INDEX', 'RECORDED_AT', 'SPEED_KPH', 'THROTTLE_PCT', 'BRAKE', 'GEAR', 'DRS', '_LOADED_AT'],
    } %}
    {{ return(contract) }}
{% endmacro %}

{#
    Value formats for the raw columns the project parses. A value that is neither a null sentinel
    (\N or empty) nor matching its pattern fails the pre-build check.
#}
{% macro raw_formats() %}
    {{ return({
        'RACES': {'RACEID': '^[0-9]+$', 'YEAR': '^[0-9]{4}$', 'ROUND': '^[0-9]+$', 'DATE': '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'},
        'RESULTS': {'POSITION_ORDER': '^[0-9]+$', 'POSITIONTEXT': '^[0-9A-Z]+$', 'POINTS': '^[0-9.]+$', 'FASTESTLAPTIME': '^[0-9]+:[0-9]{2}[.][0-9]{3}$'},
        'SPRINT_RESULTS': {'POSITION_ORDER': '^[0-9]+$'},
        'QUALIFYING': {'Q1': '^[0-9]+:[0-9]{2}[.][0-9]{3}$', 'Q2': '^[0-9]+:[0-9]{2}[.][0-9]{3}$', 'Q3': '^[0-9]+:[0-9]{2}[.][0-9]{3}$'},
        'LAP_TIMING': {'LAP': '^[0-9]+$', 'MILLISECONDS': '^[0-9]+$'},
        'PIT_STOPS': {'LAP': '^[0-9]+$', 'MILLISECONDS': '^[0-9]+$'},
        'DRIVER_STANDINGS': {'POSITION': '^[0-9]+$'},
        'DRIVERS': {'DOB': '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'},
    }) }}
{% endmacro %}

{#
    Surrogate id and natural key for each raw table. A table with 'scan': false (CAR_TELEMETRY, about
    20 million rows) is schema- and row-count-checked on every run, but its content is not scanned. The id is ignored when deciding whether
    two rows are duplicates (exact copies differ only in id). The natural key must identify
    one row once exact copies are removed.
#}
{% macro raw_keys() %}
    {{ return({
        'CIRCUITS': {'id': 'CIRCUITID', 'key': ['CIRCUITID']},
        'CONSTRUCTORS': {'id': 'CONSTRUCTORID', 'key': ['CONSTRUCTORID']},
        'CONSTRUCTOR_RESULTS': {'id': 'CONSTRUCTORRESULTSID', 'key': ['RACEID', 'CONSTRUCTORID']},
        'CONSTRUCTOR_STANDINGS': {'id': 'CONSTRUCTORSTANDINGSID', 'key': ['RACEID', 'CONSTRUCTORID']},
        'DRIVERS': {'id': 'DRIVERID', 'key': ['DRIVERID']},
        'DRIVER_STANDINGS': {'id': 'DRIVERSTANDINGSID', 'key': ['RACEID', 'DRIVERID']},
        'LAP_TIMING': {'id': none, 'key': ['RACEID', 'DRIVERID', 'LAP']},
        'PIT_STOPS': {'id': none, 'key': ['RACEID', 'DRIVERID', 'STOP']},
        'QUALIFYING': {'id': 'QUALIFYID', 'key': ['QUALIFYID']},
        'RACES': {'id': 'RACEID', 'key': ['RACEID']},
        'RESULTS': {'id': 'RESULTID', 'key': ['RESULTID']},
        'SEASONS': {'id': 'YEAR', 'key': ['YEAR']},
        'SPRINT_RESULTS': {'id': 'RESULTID', 'key': ['RESULTID']},
        'STATUS': {'id': 'STATUSID', 'key': ['STATUSID']},
        'VB_DRIVERS': {'id': 'DRIVER_KEY', 'key': ['DRIVER_KEY']},
        'VB_SESSIONS': {'id': 'SESSION_KEY', 'key': ['SESSION_KEY']},
        'VB_RESULTS': {'id': none, 'key': ['SESSION_KEY', 'DRIVER_KEY']},
        'CAR_TELEMETRY': {'id': none, 'key': none, 'scan': false},
    }) }}
{% endmacro %}

{#
    Runs before any model or test (on-run-start). Stops the run, before anything is built, when:
      1. a table or column is missing, renamed or new (schema contract);
      2. a natural key has rows with conflicting content (same key, different values);
      3. a raw table has fewer rows than at the last successful build (truncated load).
    Exact duplicates (same content, different id, text compared after trim) are not an error;
    dedupe_raw removes them.
    The row counts behind check 3 are recorded by the raw_row_count_log model.
#}
{% macro assert_raw_contract() %}
    {% if execute %}
        {% set raw = source('f1_raw', 'RACES') %}
        {% set contract = raw_contract() %}
        {% set keys = raw_keys() %}
        {% set problems = [] %}

        {# 1. schema contract #}
        {% set expected = [] %}
        {% for table_name, columns in contract.items() %}
            {% for column_name in columns %}
                {% do expected.append(table_name ~ '.' ~ column_name) %}
            {% endfor %}
        {% endfor %}
        {% set actual_query %}
            select table_name || '.' || column_name
            from {{ raw.database }}.information_schema.columns
            where table_schema = '{{ raw.schema }}'
        {% endset %}
        {% set actual = run_query(actual_query).columns[0].values() %}
        {% set missing = [] %}
        {% for item in expected if item not in actual %}
            {% do missing.append(item) %}
        {% endfor %}
        {% set unexpected = [] %}
        {% for item in actual if item not in expected %}
            {% do unexpected.append(item) %}
        {% endfor %}
        {% if missing %}
            {% do problems.append('Missing columns (in the contract, not in the feed): ' ~ missing | join(', ')) %}
        {% endif %}
        {% if unexpected %}
            {% do problems.append('Unexpected columns (in the feed, not in the contract): ' ~ unexpected | join(', ')) %}
        {% endif %}

        {# 2. conflicting rows for the same natural key #}
        {% for table_name, columns in contract.items() %}
            {% set spec = keys[table_name] %}
            {% if spec.get('scan', true) %}
            {% set content = columns | reject('equalto', spec.id) | list if spec.id else columns %}
            {% set select_cols = [] %}
            {% for column_name in spec.key + content %}
                {% if column_name not in select_cols %}{% do select_cols.append(column_name) %}{% endif %}
            {% endfor %}
            {% set conflict_query %}
                select count(*) as conflicts
                from (
                    select {{ spec.key | join(', ') }}
                    from (
                        select distinct {% for c in select_cols %}trim({{ c }}) as {{ c }}{{ ', ' if not loop.last }}{% endfor %}
                        from {{ raw.database }}.{{ raw.schema }}.{{ table_name }}
                    )
                    group by {{ spec.key | join(', ') }}
                    having count(*) > 1
                )
            {% endset %}
            {% set conflicts = run_query(conflict_query).columns[0].values()[0] %}
            {% if conflicts > 0 %}
                {% do problems.append(table_name ~ ': ' ~ conflicts ~ ' key(s) (' ~ spec.key | join(', ') ~ ') have rows with conflicting content') %}
            {% endif %}
            {% endif %}
        {% endfor %}

        {# 3. row counts must not drop below the last successful build #}
        {% set audit_relation = adapter.get_relation(database=target.database, schema=target.schema ~ '_audit', identifier='raw_row_count_log') %}
        {% if audit_relation is not none %}
            {% set last_counts_query %}
                select table_name, row_count
                from {{ audit_relation }}
                qualify row_number() over (partition by table_name order by loaded_at desc) = 1
            {% endset %}
            {% set last_rows = run_query(last_counts_query).rows %}
            {% set last_counts = {} %}
            {% for row in last_rows %}
                {% do last_counts.update({row[0]: row[1]}) %}
            {% endfor %}
            {% set current_query %}
                {% for table_name in contract.keys() %}
                select '{{ table_name }}' as table_name, count(*) as row_count from {{ raw.database }}.{{ raw.schema }}.{{ table_name }}
                {{ 'union all' if not loop.last }}
                {% endfor %}
            {% endset %}
            {% for row in run_query(current_query).rows %}
                {% set previous = last_counts.get(row[0]) %}
                {% if previous is not none and row[1] < previous %}
                    {% do problems.append(row[0] ~ ': row count fell from ' ~ previous ~ ' to ' ~ row[1] ~ ' (truncated load?)') %}
                {% endif %}
            {% endfor %}
        {% endif %}

        {# 4. value formats #}
        {% set format_parts = [] %}
        {% for table_name, columns in raw_formats().items() %}
            {% for column_name, pattern in columns.items() %}
                {% do format_parts.append(
                    "select '" ~ table_name ~ "." ~ column_name ~ "' as column_name, count(*) as bad_values "
                    ~ "from " ~ raw.database ~ "." ~ raw.schema ~ "." ~ table_name ~ " "
                    ~ "where " ~ column_name ~ " is not null and " ~ column_name ~ " not in ('\\\\N', '') "
                    ~ "and not regexp_like(" ~ column_name ~ ", '" ~ pattern ~ "')"
                ) %}
            {% endfor %}
        {% endfor %}
        {% for row in run_query(format_parts | join(' union all ')).rows %}
            {% if row[1] > 0 %}
                {% do problems.append(row[0] ~ ': ' ~ row[1] ~ ' value(s) do not match the expected format') %}
            {% endif %}
        {% endfor %}

        {% if problems %}
            {% set message %}
RAW FEED FAILED PRE-BUILD CHECKS: {{ raw.database }}.{{ raw.schema }}
{% for problem in problems %}- {{ problem }}
{% endfor %}
No models were built, so the dashboards still show the last good build. Fix the feed, or if the
change is intended, update macros/raw_contract.sql (schema) or the staging models, then rerun.
            {% endset %}
            {{ exceptions.raise_compiler_error(message) }}
        {% endif %}
    {% endif %}
{% endmacro %}
