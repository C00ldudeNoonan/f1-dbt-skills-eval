{#
    Count of fact rows whose driver has no record in stg_f1__drivers, by source table
    and season. A view, so it always reflects the current data. Use it to see how many
    late-arriving driver rows are waiting for their driver record.
#}
{{ config(materialized='view') }}

with orphan_rows as (

    select
        references.source_table,
        races.season,
        references.driver_id,
        references.race_id

    from {{ ref('int_driver_references') }} as references
    inner join {{ ref('stg_f1__races') }} as races
        on references.race_id = races.race_id
    inner join {{ ref('int_orphan_driver_ids') }} as orphans
        on references.driver_id = orphans.driver_id

)

select
    source_table,
    season,
    count(*) as orphan_rows,
    count(distinct driver_id) as orphan_drivers,
    count(distinct race_id) as races_affected

from orphan_rows
group by source_table, season
