-- The lap summary must account for every sample in fct_telemetry. This is the
-- pipeline's own consistency, so a mismatch is an error. The count over
-- fct_telemetry comes from metadata, and the sum reads only the small
-- summary table (about 80k rows).
with counts as (
    select
        (select count(*) from {{ ref('fct_telemetry') }}) as fact_samples,
        (select sum(samples) from {{ ref('mart_lap_telemetry_summary') }}) as summarised_samples
)

select *
from counts
where fact_samples <> summarised_samples
