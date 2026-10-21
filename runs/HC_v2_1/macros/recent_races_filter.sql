{#
    Limits an incremental run to races that are new or among the two most recent races
    already loaded. The timing provider reissues corrected lap times for those two races,
    so they are reprocessed on every run. Older races are left alone.

    Use inside the WHERE clause of a CTE that selects from stg_f1__races.
#}
{% macro recent_races_filter(race_date_column) -%}
    {%- if is_incremental() %}
    and {{ race_date_column }} >= (
        select min(race_date)
        from (
            select distinct race_date
            from {{ this }}
            order by race_date desc
            limit 2
        )
    )
    {%- endif %}
{%- endmacro %}
