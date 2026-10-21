select
    constructor_id,
    constructor_ref,
    constructor_name,
    nationality
from {{ ref('stg_ergast__constructors') }}
