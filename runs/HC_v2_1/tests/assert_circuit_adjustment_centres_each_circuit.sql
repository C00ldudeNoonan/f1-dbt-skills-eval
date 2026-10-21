{#
    Within each stable circuit the adjusted stop times must have a median of about zero, since the adjustment subtracts
    the circuit's median. The mean is not centred, because stop times have a long slow tail, so the median is the test.
    A sizeable median means the circuit median was computed on different rows.
#}
select
    circuit_id,
    median(seconds_vs_circuit) as median_adjusted
from {{ ref('int_pit_stops_circuit_adjusted') }}
where circuit_is_stable
group by circuit_id
having abs(median(seconds_vs_circuit)) > 0.05
