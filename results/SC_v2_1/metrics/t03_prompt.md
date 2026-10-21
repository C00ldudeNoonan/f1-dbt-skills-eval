Two dimension problems:

1. **History.** Drivers change their car numbers and codes over time, and raw `drivers` only holds the current values. Add a snapshot named `snp_drivers` that tracks changes to it (type 2), and add a `current_number` column to `dim_drivers` (null if a driver has no permanent number).
2. **Late-arriving drivers.** With rookies and reserve drivers, the results feed sometimes delivers a race result *before* the driver's record appears in `drivers`. Right now that result would silently disappear or break things. From now on:
   - Those results must still appear in `fct_results` and everything downstream.
   - `dim_drivers` must contain a placeholder row for any such driver_id until the real record arrives, and then show the real values on the next run, with no manual steps.
   - We should be able to see how many such orphan results exist at any time.

Make sure `dbt build` succeeds when you're done.
