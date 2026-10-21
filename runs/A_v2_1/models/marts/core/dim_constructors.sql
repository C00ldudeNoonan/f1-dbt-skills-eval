-- One row per constructor (team entry name). Exists mainly so the Semantic
-- Layer can slice by constructor through the constructor entity.
select
    constructor_id,
    constructor_ref,
    constructor_name,
    nationality,
    url
from {{ ref('stg_ergast__constructors') }}
