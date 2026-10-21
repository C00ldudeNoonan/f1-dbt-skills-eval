{#
    Incremental filter on the load watermark. Selects the races that have samples loaded after the target's last
    load, minus a 48-hour lookback so a clock skew or a delayed batch cannot slip between runs. Only races that
    changed are rebuilt, so a routine run never rescans old races.

    Pass the table to compare against, its loaded_at column, and the lookback in hours.
#}
{% macro changed_races_since_last_load(source_relation, loaded_at_column, watermark_column, lookback_hours=48) -%}
    select distinct race_id
    from {{ source_relation }}
    {%- if is_incremental() %}
    where {{ loaded_at_column }} > (
        select dateadd(hour, -{{ lookback_hours }}, max({{ watermark_column }}))
        from {{ this }}
    )
    {%- endif %}
{%- endmacro %}
