{#
  Parsing helpers for the raw Ergast/Kaggle F1 tables.
  Every raw column is text, exactly as written in the CSVs: nulls are the
  literal string \N, and a few cells are empty strings or carry stray
  whitespace. Always go through these macros in staging rather than casting
  directly, so the rules live in one place.
#}

{% macro clean_text(column) -%}
    nullif(nullif(trim({{ column }}), '\\N'), '')
{%- endmacro %}

{#
  Regex-guarded casts. Don't use try_to_number() on its own: Snowflake parses
  some non-numeric strings (for example 'E') as 0.
#}
{% macro to_integer(column) -%}
    case
        when regexp_like({{ clean_text(column) }}, '^-?[0-9]+$')
            then {{ clean_text(column) }}::integer
    end
{%- endmacro %}

{% macro to_decimal(column, precision=12, scale=3) -%}
    case
        when regexp_like({{ clean_text(column) }}, '^-?[0-9]+([.][0-9]+)?$')
            then {{ clean_text(column) }}::number({{ precision }}, {{ scale }})
    end
{%- endmacro %}

{#
  Converts a lap/session time string to integer milliseconds.
  Accepts 'h:mm:ss.sss', 'm:ss.sss' and 'ss.sss'. Anything else returns null.
#}
{% macro time_to_ms(column) -%}
    {%- set t = clean_text(column) -%}
    case
        when regexp_like({{ t }}, '^[0-9]+:[0-9]{1,2}:[0-9]{1,2}([.][0-9]+)?$')
            then (
                split_part({{ t }}, ':', 1)::integer * 3600000
                + split_part({{ t }}, ':', 2)::integer * 60000
                + round(split_part({{ t }}, ':', 3)::number(10, 3) * 1000)
            )::integer
        when regexp_like({{ t }}, '^[0-9]+:[0-9]{1,2}([.][0-9]+)?$')
            then (
                split_part({{ t }}, ':', 1)::integer * 60000
                + round(split_part({{ t }}, ':', 2)::number(10, 3) * 1000)
            )::integer
        when regexp_like({{ t }}, '^[0-9]+([.][0-9]+)?$')
            then round({{ t }}::number(10, 3) * 1000)::integer
    end
{%- endmacro %}

{#
  Keeps one row per natural key. The vendor has resent rows: a Ferrari
  constructor row duplicated with a trailing space, and a batch of standings
  resent under new ids. Unhandled, duplicate dimension rows fan out joins
  (Ferrari's wins and points doubled). Staging drops the extras so a plain
  `dbt run` can't publish inflated numbers. The source tests still report
  every duplicate (warn), and fail the build when duplicates disagree on
  content (see `duplicates_are_identical`), because then there's no safe row
  to keep. `order_by` decides which copy is kept, normally the original (lowest) id.
#}
{% macro deduplicate(partition_by, order_by) -%}
qualify row_number() over (partition by {{ partition_by }} order by {{ order_by }}) = 1
{%- endmacro %}

{#
  Wilson score interval bound for a proportion (successes / trials) at 95%
  confidence. Better behaved than the normal approximation for small samples
  and rates near 0 or 1. Returns null when trials is 0.
#}
{% macro wilson_bound(successes, trials, side='lower', z=1.96) -%}
    {%- set rate = '(' ~ successes ~ ' / ' ~ trials ~ ')' -%}
    {%- set bound -%}
        (
            {{ rate }} + {{ z }} * {{ z }} / (2 * {{ trials }})
            {{ '-' if side == 'lower' else '+' }} {{ z }} * sqrt(
                {{ rate }} * (1 - {{ rate }}) / {{ trials }}
                + {{ z }} * {{ z }} / (4 * {{ trials }} * {{ trials }})
            )
        ) / (1 + {{ z }} * {{ z }} / {{ trials }})
    {%- endset -%}
    {#- Clamped so floating-point error can't put the bound on the wrong side of the rate. -#}
    case when {{ trials }} > 0 then
        {% if side == 'lower' -%}
        least({{ rate }}, greatest(0, {{ bound }}))
        {%- else -%}
        greatest({{ rate }}, least(1, {{ bound }}))
        {%- endif %}
    end
{%- endmacro %}
