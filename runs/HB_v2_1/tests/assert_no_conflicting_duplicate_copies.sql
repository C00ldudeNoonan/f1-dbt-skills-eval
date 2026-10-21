{#
    Duplicate keys in the raw feed are allowed only when every copy is identical, because
    staging keeps one copy. A duplicate key whose copies differ means the feed is
    contradicting itself, so the build fails.
#}
select
    'constructors' as table_name,
    cast(constructorid as string) as duplicated_key,
    count(*) as copies

from {{ source('f1_raw', 'constructors') }}
group by constructorid
having count(distinct hash(
    trim(constructorref), trim(name), trim(nationality)
)) > 1

union all

select
    'driver_standings' as table_name,
    raceid || '/' || driverid as duplicated_key,
    count(*) as copies

from {{ source('f1_raw', 'driver_standings') }}
group by raceid, driverid
having count(distinct hash(
    points, position, positiontext, wins
)) > 1
