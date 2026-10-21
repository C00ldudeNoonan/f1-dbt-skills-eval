{#
    Driver ids that appear in the fact data but have no record in stg_f1__drivers yet.
    dim_drivers adds a placeholder row for each. The placeholder is replaced by the real
    record on the first run after the record arrives.
#}
select distinct references.driver_id

from {{ ref('int_driver_references') }} as references
where references.driver_id is not null
    and not exists (
        select 1
        from {{ ref('stg_f1__drivers') }} as drivers
        where drivers.driver_id = references.driver_id
    )
