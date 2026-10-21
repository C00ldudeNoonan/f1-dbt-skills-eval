{#- Incremental reload predicate for race-grained tables.

    Selects races that are not yet in {{ this }} (new Grands Prix) or that are one of
    the `lookback` most recent races already in it (the timing provider reissues
    corrected data for those). Pair with incremental_strategy='delete+insert' and
    unique_key='race_id' so a reloaded race fully replaces its old rows, including
    laps that a correction removed.

    `race_order_expr` is a SQL expression over the incoming relation that orders races
    chronologically; `target_order_expr` is the same ordering over {{ this }}. -#}
{% macro recent_races_filter(race_order_expr, target_order_expr, lookback=2) -%}
    {{ race_order_expr }} >= coalesce(
        (
            select min(race_order)
            from (
                select distinct {{ target_order_expr }} as race_order
                from {{ this }}
                order by race_order desc
                limit {{ lookback }}
            )
        ),
        0
    )
    or race_id not in (select race_id from {{ this }})
{%- endmacro %}
