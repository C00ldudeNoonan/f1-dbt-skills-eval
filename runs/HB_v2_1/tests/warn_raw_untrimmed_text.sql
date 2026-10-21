{{ config(severity='warn') }}
{#
    Raw text with leading or trailing spaces. Staging trims it, so numbers are unaffected,
    but a space in a name is a sign the feed is being edited by hand.
#}
select 'constructors' as table_name, constructorid as row_key
from {{ source('f1_raw', 'constructors') }}
where name <> trim(name) or constructorref <> trim(constructorref) or nationality <> trim(nationality)

union all

select 'drivers', driverid
from {{ source('f1_raw', 'drivers') }}
where forename <> trim(forename) or surname <> trim(surname) or driverref <> trim(driverref) or nationality <> trim(nationality)
