-- Migration window guard for dim_drivers. Until v1 is removed (deprecated
-- 2027-01-01), the v1 relation must remain a table with the v1 shape
-- (full_name), and v2 must be a separate relation. Catches the failure seen
-- during the v2 rollout, where a latest-version pointer view silently replaced
-- DIM_DRIVERS with a view of v2.

{% set v1 = ref('dim_drivers', v=1) %}
{% set v2 = ref('dim_drivers', v=2) %}

-- Two filtered lookups rather than a join: joining information_schema views
-- stops Snowflake applying the table filter and takes minutes.
with v1_relation as (
    select
        (
            select max(table_type)
            from {{ v1.database }}.information_schema.tables
            where table_schema = upper('{{ v1.schema }}')
                and table_name = upper('{{ v1.identifier }}')
        ) as table_type,
        (
            select count(*)
            from {{ v1.database }}.information_schema.columns
            where table_schema = upper('{{ v1.schema }}')
                and table_name = upper('{{ v1.identifier }}')
                and column_name = 'FULL_NAME'
        ) as has_full_name
)

select
    '{{ v1.identifier }}' as relation,
    table_type,
    has_full_name
from v1_relation
where table_type is distinct from 'BASE TABLE'
    or has_full_name = 0
    or upper('{{ v1.identifier }}') = upper('{{ v2.identifier }}')
