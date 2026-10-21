{{ config(severity='warn') }}
{#
    Vendor B session start times that do not parse as a full timestamp. The session date is
    still read from the first ten characters, so matching works, but the vendor should fix the
    feed.
#}
select session_key, season, session_type
from {{ ref('stg_vendor_b__sessions') }}
where session_start_utc is null
