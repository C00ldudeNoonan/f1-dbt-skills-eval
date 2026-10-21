-- Same constructor_id with different attributes (ignoring whitespace) in the raw feed: dedupe would pick arbitrarily.
select constructorid
from {{ source('f1_raw', 'constructors') }}
group by constructorid
having count(distinct trim(constructorref) || '|' || trim(name) || '|' || coalesce(trim(nationality), '')) > 1
