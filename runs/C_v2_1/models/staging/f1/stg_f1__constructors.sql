with source as (
    select * from {{ source('f1_raw', 'constructors') }}
)

select
    {{ to_integer('constructorid') }} as constructor_id,
    {{ clean_text('constructorref') }} as constructor_ref,
    {{ clean_text('name') }} as constructor_name,
    {{ clean_text('nationality') }} as nationality,
    {{ clean_text('url') }} as wikipedia_url
from source
{{ deduplicate('constructor_id', 'constructor_id') }}
