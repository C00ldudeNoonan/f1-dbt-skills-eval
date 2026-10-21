{{ config(severity='warn') }}
{#
    Exact duplicate copies in the raw feed. Staging removes them, so numbers are still
    correct, but the vendor should be told. Lists each duplicated key and its copy count.
#}
select
    'constructors' as table_name,
    cast(constructorid as string) as duplicated_key,
    count(*) as copies

from {{ source('f1_raw', 'constructors') }}
group by constructorid
having count(*) > 1

union all

select
    'driver_standings' as table_name,
    raceid || '/' || driverid as duplicated_key,
    count(*) as copies

from {{ source('f1_raw', 'driver_standings') }}
group by raceid, driverid
having count(*) > 1
