Drivers change their car numbers and codes over time, and we've been losing that history: `drivers` in raw only holds the current values.

1. Add a snapshot named `snp_drivers` that tracks changes to the raw drivers table (type 2 history).
2. Add a `current_number` column to `dim_drivers` with each driver's current permanent number (null if they don't have one).

Make sure `dbt build` succeeds when you're done.
