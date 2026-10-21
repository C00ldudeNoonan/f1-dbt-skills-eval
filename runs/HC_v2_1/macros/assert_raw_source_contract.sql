{#
    Runs before any model (on-run-start in dbt_project.yml). It checks that the raw vendor schema still
    looks the way the staging models expect, and stops the run with a message naming each mismatch if not.

    The contract below is the record of what this project reads from the vendor. Update it in the same change
    as the staging models when the vendor changes something, so the change is visible in review:
      - columns: every column a staging model reads, under the identifier the source uses.
      - min_rows: row count floor. Loads only grow, so a count below the floor means rows went missing.
      - formats: columns whose text format the staging models parse, with the accepted pattern.
        The null sentinel (\N) and empty strings are always accepted.

    2026-10-21 migration: LAP_TIMES became LAP_TIMING, POSITIONORDER became POSITION_ORDER, PIT_STOPS.DURATION
    was dropped (not read), RACES.DATE moved from ISO to DD/MM/YYYY, and qualifying nulls moved from \N to ''.
#}
{% macro assert_raw_source_contract() %}
    {% if not execute %}
        {{ return('') }}
    {% endif %}

    {% set iso = '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' %}
    {% set iso_or_dmy = '^([0-9]{4}-[0-9]{2}-[0-9]{2}|[0-9]{2}/[0-9]{2}/[0-9]{4})$' %}
    {% set lap_time = '^[0-9]+:[0-5][0-9]\\.[0-9]{3}$' %}

    {% set contract = {
        'RACES': {
            'columns': ['RACEID','YEAR','ROUND','CIRCUITID','NAME','DATE','TIME'],
            'min_rows': 1125,
            'formats': {'DATE': iso_or_dmy}
        },
        'RESULTS': {
            'columns': ['RESULTID','RACEID','DRIVERID','CONSTRUCTORID','NUMBER','GRID','POSITION','POSITIONTEXT','POSITION_ORDER','POINTS','LAPS','MILLISECONDS','FASTESTLAP','RANK','FASTESTLAPTIME','STATUSID'],
            'min_rows': 26760,
            'formats': {'FASTESTLAPTIME': lap_time}
        },
        'SPRINT_RESULTS': {
            'columns': ['RESULTID','RACEID','DRIVERID','CONSTRUCTORID','GRID','POSITION','POSITIONTEXT','POSITION_ORDER','POINTS','LAPS','MILLISECONDS','FASTESTLAPTIME','STATUSID'],
            'min_rows': 360,
            'formats': {'FASTESTLAPTIME': lap_time}
        },
        'DRIVERS': {
            'columns': ['DRIVERID','DRIVERREF','NUMBER','CODE','FORENAME','SURNAME','DOB','NATIONALITY'],
            'min_rows': 862,
            'formats': {'DOB': iso}
        },
        'DRIVER_STANDINGS': {
            'columns': ['DRIVERSTANDINGSID','RACEID','DRIVERID','POINTS','POSITION','POSITIONTEXT','WINS'],
            'min_rows': 34863,
            'formats': {}
        },
        'CONSTRUCTORS': {
            'columns': ['CONSTRUCTORID','CONSTRUCTORREF','NAME','NATIONALITY'],
            'min_rows': 212,
            'formats': {}
        },
        'STATUS': {
            'columns': ['STATUSID','STATUS'],
            'min_rows': 139,
            'formats': {}
        },
        'QUALIFYING': {
            'columns': ['QUALIFYID','RACEID','DRIVERID','CONSTRUCTORID','NUMBER','POSITION','Q1','Q2','Q3'],
            'min_rows': 10494,
            'formats': {'Q1': lap_time, 'Q2': lap_time, 'Q3': lap_time}
        },
        'LAP_TIMING': {
            'columns': ['RACEID','DRIVERID','LAP','POSITION','MILLISECONDS'],
            'min_rows': 589081,
            'formats': {}
        },
        'PIT_STOPS': {
            'columns': ['RACEID','DRIVERID','STOP','LAP','MILLISECONDS'],
            'min_rows': 11371,
            'formats': {}
        },
        'VB_DRIVERS': {
            'columns': ['DRIVER_KEY','FULL_NAME','ABBREVIATION','RACING_NUMBER'],
            'min_rows': 41,
            'formats': {}
        },
        'VB_SESSIONS': {
            'columns': ['SESSION_KEY','SESSION_TYPE','MEETING_NAME','YEAR','DATE_START'],
            'min_rows': 167,
            'formats': {}
        },
        'VB_RESULTS': {
            'columns': ['SESSION_KEY','DRIVER_KEY','TEAM_NAME','GRID_POSITION','POSITION','POINTS'],
            'min_rows': 3337,
            'formats': {}
        },
        'CAR_TELEMETRY': {
            'columns': ['RACEID','DRIVERID','LAP','SAMPLE_INDEX','RECORDED_AT','SPEED_KPH','THROTTLE_PCT','BRAKE','GEAR','DRS','_LOADED_AT'],
            'min_rows': 19809360,
            'formats': {}
        }
    } %}

    {% set db = var('raw_database') %}
    {% set sch = var('raw_schema') %}
    {% set problems = [] %}

    {# SHOW and a limit-0 select are cheap. INFORMATION_SCHEMA scans every schema in the account and is slow. #}
    {% set present_tables = [] %}
    {% for r in run_query("show tables in schema " ~ db ~ "." ~ sch).rows %}
        {% do present_tables.append(r[1] | upper) %}
    {% endfor %}

    {% for table, spec in contract.items() %}
        {% if table not in present_tables %}
            {% do problems.append("table " ~ table ~ " is missing from " ~ db ~ "." ~ sch ~ " (renamed by the vendor?)") %}
        {% else %}
            {% set fq = db ~ "." ~ sch ~ "." ~ table %}
            {% set present_cols = run_query("select * from " ~ fq ~ " limit 0").columns | map(attribute='name') | map('upper') | list %}
            {% for col in spec['columns'] %}
                {% if col not in present_cols %}
                    {% do problems.append("column " ~ table ~ "." ~ col ~ " is missing (renamed or dropped by the vendor?)") %}
                {% endif %}
            {% endfor %}

            {# One aggregate query per table: row count, then one bad-row count per format rule #}
            {% set checks = [] %}
            {% set format_list = spec['formats'].items() | list %}
            {% for col, pattern in format_list %}
                {% do checks.append("count_if(" ~ col ~ " is not null and not regexp_like(" ~ col ~ ", '" ~ pattern ~ "') and trim(" ~ col ~ ") not in ('', chr(92) || 'N'))") %}
            {% endfor %}
            {% set agg = run_query("select count(*)" ~ (", " ~ checks | join(", ") if checks | length > 0 else "") ~ " from " ~ fq).rows[0] %}
            {% if agg[0] < spec['min_rows'] %}
                {% do problems.append("table " ~ table ~ " has " ~ agg[0] ~ " rows, below the contract floor of " ~ spec['min_rows'] ~ " (rows missing?)") %}
            {% endif %}
            {% for col, pattern in format_list %}
                {% if agg[loop.index] > 0 %}
                    {% do problems.append(agg[loop.index] ~ " rows in " ~ table ~ "." ~ col ~ " do not match the expected format " ~ pattern ~ " (format changed by the vendor?)") %}
                {% endif %}
            {% endfor %}
        {% endif %}
    {% endfor %}

    {# Keys: a key repeated with identical values is collapsed in staging (logged here). A key repeated with
       different values is a conflict and stops the run. #}
    {% set key_contract = {
        'RESULTS': {'keys': ['RESULTID'], 'values': ['RACEID','DRIVERID','CONSTRUCTORID','POSITION','POSITIONTEXT','POSITION_ORDER','POINTS']},
        'SPRINT_RESULTS': {'keys': ['RESULTID'], 'values': ['RACEID','DRIVERID','CONSTRUCTORID','POSITION','POSITIONTEXT','POSITION_ORDER','POINTS']},
        'RACES': {'keys': ['RACEID'], 'values': ['YEAR','ROUND','CIRCUITID','NAME','DATE']},
        'DRIVERS': {'keys': ['DRIVERID'], 'values': ['DRIVERREF','NUMBER','CODE','FORENAME','SURNAME','DOB','NATIONALITY']},
        'CONSTRUCTORS': {'keys': ['CONSTRUCTORID'], 'values': ['CONSTRUCTORREF','NAME','NATIONALITY']},
        'DRIVER_STANDINGS': {'keys': ['RACEID','DRIVERID'], 'values': ['POINTS','POSITION','POSITIONTEXT','WINS']},
        'STATUS': {'keys': ['STATUSID'], 'values': ['STATUS']},
        'QUALIFYING': {'keys': ['QUALIFYID'], 'values': ['RACEID','DRIVERID','CONSTRUCTORID','POSITION','Q1','Q2','Q3']},
        'LAP_TIMING': {'keys': ['RACEID','DRIVERID','LAP'], 'values': ['POSITION','MILLISECONDS']},
        'PIT_STOPS': {'keys': ['RACEID','DRIVERID','STOP'], 'values': ['LAP','MILLISECONDS']},
        'VB_RESULTS': {'keys': ['SESSION_KEY','DRIVER_KEY'], 'values': ['TEAM_NAME','POSITION','POINTS']}
    } %}
    {% for table, spec in key_contract.items() %}
        {% if table in present_tables %}
            {% set fq = db ~ "." ~ sch ~ "." ~ table %}
            {% set keys = spec['keys'] | join(', ') %}
            {% set value_parts = [] %}
            {% for v in spec['values'] %}{% do value_parts.append("coalesce(trim(" ~ v ~ "), '<null>')") %}{% endfor %}
            {% set value_expr = "concat_ws('|', " ~ (value_parts | join(", ")) ~ ")" %}
            {% set rows = run_query("select count_if(n > 1), count_if(distinct_values > 1) from (select " ~ keys ~ ", count(*) as n, count(distinct " ~ value_expr ~ ") as distinct_values from " ~ fq ~ " group by " ~ keys ~ ")").rows[0] %}
            {% if rows[1] > 0 %}
                {% do problems.append(rows[1] ~ " keys in " ~ table ~ " (" ~ keys ~ ") repeat with different values: a conflict the staging models cannot resolve") %}
            {% elif rows[0] > 0 %}
                {{ log("NOTE: " ~ rows[0] ~ " identical duplicate keys in " ~ table ~ " (" ~ keys ~ ") are collapsed in staging.", info=True) }}
            {% endif %}
        {% endif %}
    {% endfor %}

    {# Value rules: numeric ranges that no valid row breaks #}
    {% set value_rules = [
        ['RESULTS', 'POINTS', 0, 50],
        ['RESULTS', 'POSITION_ORDER', 1, 40],
        ['SPRINT_RESULTS', 'POINTS', 0, 50],
        ['DRIVER_STANDINGS', 'POINTS', 0, 1000],
        ['DRIVER_STANDINGS', 'WINS', 0, 200],
        ['LAP_TIMING', 'MILLISECONDS', 1000, 10000000],
        ['PIT_STOPS', 'MILLISECONDS', 1000, 10000000]
    ] %}
    {% for rule in value_rules %}
        {% if rule[0] in present_tables %}
            {% set bad = run_query("select count_if(try_to_number(" ~ rule[1] ~ ") < " ~ rule[2] ~ " or try_to_number(" ~ rule[1] ~ ") > " ~ rule[3] ~ ") from " ~ db ~ "." ~ sch ~ "." ~ rule[0]).rows[0][0] %}
            {% if bad > 0 %}
                {% do problems.append(bad ~ " rows in " ~ rule[0] ~ "." ~ rule[1] ~ " are outside " ~ rule[2] ~ " to " ~ rule[3] ~ " (corrupt values?)") %}
            {% endif %}
        {% endif %}
    {% endfor %}

    {% if problems | length > 0 %}
        {% set bullets = [] %}
        {% for p in problems %}{% do bullets.append("  - " ~ p) %}{% endfor %}
        {% set message = "\n\nRAW SOURCE CONTRACT BROKEN: the vendor data in " ~ db ~ "." ~ sch ~ " no longer matches what this project reads.\n" ~ (bullets | join("\n")) ~ "\n\nNo model was built. Fix the source identifier, column or parser in models/staging, then update the contract in macros/assert_raw_source_contract.sql in the same change. Check the marts against the pre-change tables before merging.\n" %}
        {{ exceptions.raise_compiler_error(message) }}
    {% endif %}
{% endmacro %}
