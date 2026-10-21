"""Mutate a run's raw data between tasks.

usage: inject.py RUN_ID {setup|arrive1|arrive2|correct_laps|driver_change|drift|dup_constructor|teardown}

Legit data changes (arrivals, corrections, driver changes) go to BOTH the agent's raw schema
and the truth schema. Breakage (drift, dup_constructor) goes to the raw schema ONLY, so the
answer keys always reflect what correct output should be.
"""
import sys

from sf import CFG, connect, run, run_schemas
import v2_extras as vx

RACE_TABLES = [
    "RESULTS", "SPRINT_RESULTS", "LAP_TIMES", "PIT_STOPS", "QUALIFYING",
    "DRIVER_STANDINGS", "CONSTRUCTOR_STANDINGS", "CONSTRUCTOR_RESULTS",
]


def tables(conn, schema):
    return {r[1] for r in run(conn, f"show tables in schema {schema}")}


def arrive(conn, s, arrival: int):
    hold = CFG["SF_HOLDOUT_SCHEMA"]
    for schema in (s["raw"], s["truth"]):
        have = tables(conn, schema)
        for t in RACE_TABLES:
            if t not in have:
                continue
            # Insert by column name so this still works after the drift step renames columns.
            cols = [r[2] for r in run(conn, f"show columns in table {schema}.{t}")]
            src_cols = {r[2] for r in run(conn, f"show columns in table {hold}.{t}")}
            renames = {"POSITION_ORDER": "POSITIONORDER"}
            sel = ", ".join(
                (renames.get(c, c) if renames.get(c, c) in src_cols else "null") + f" as {c}" for c in cols
            )
            run(conn, f"""
                insert into {schema}.{t} ({", ".join(cols)})
                select {sel} from {hold}.{t}
                where raceid in (select raceid from {hold}._HELD_RACES where arrival = {arrival})
            """)


def correct_laps(conn, s):
    """The timing vendor reissues corrected lap times for the second-most-recent race,
    which the agent's incremental model has already loaded."""
    for schema in (s["raw"], s["truth"]):
        run(conn, f"""
            update {schema}.lap_times set milliseconds = (milliseconds::int + 137)::varchar
            where raceid = (
              select r.raceid from {schema}.races r
              where exists (select 1 from {schema}.lap_times l where l.raceid = r.raceid)
              qualify row_number() over (order by r.year::int desc, r.round::int desc) = 2
            ) and lap::int between 10 and 20
        """)


def driver_change(conn, s):
    for schema in (s["raw"], s["truth"]):
        run(conn, f"update {schema}.drivers set number = '3' where driverref = 'max_verstappen'")
        run(conn, f"update {schema}.drivers set number = '12' where driverref = 'sainz'")


def drift(conn, s):
    raw = s["raw"]
    run(conn, f"alter table {raw}.results rename column positionorder to position_order")
    if "SPRINT_RESULTS" in tables(conn, raw):
        run(conn, f"alter table {raw}.sprint_results rename column positionorder to position_order")
    run(conn, f"alter table {raw}.pit_stops drop column duration")


def dup_constructor(conn, s):
    raw = s["raw"]
    cols = [r[2] for r in run(conn, f"show columns in table {raw}.constructors")]
    sel = ", ".join("name || ' '" if c == "NAME" else c for c in cols)
    run(conn, f"insert into {raw}.constructors select {sel} from {raw}.constructors where constructorref = 'ferrari'")


def setup(conn, s):
    p = CFG["SF_PRISTINE_SCHEMA"]
    run(conn, f"create or replace schema {s['raw']} clone {p}")
    run(conn, f"create or replace schema {s['truth']} clone {p}")


def teardown(conn, s):
    for k in ("raw", "truth"):
        run(conn, f"drop schema if exists {s[k]}")
    for (name,) in [(r[1],) for r in run(conn, f"show schemas like '{s['target']}%'")]:
        if name == s["target"] or name.startswith(s["target"] + "_") and not name[len(s["target"]) + 1:].isdigit():
            run(conn, f"drop schema if exists {name}")


# ---------- v2 suite ----------
ORPHAN_RESULT_ID, ORPHAN_DRIVER_ID = "99001", "9001"


def orphan_result(conn, s):
    """A reserve driver's result lands before their driver record (race 1143, Haas)."""
    row = {"RESULTID": ORPHAN_RESULT_ID, "RACEID": "1143", "DRIVERID": ORPHAN_DRIVER_ID, "CONSTRUCTORID": "210",
           "NUMBER": "50", "GRID": "20", "POSITION": r"\N", "POSITIONTEXT": "R", "POSITIONORDER": "21",
           "POINTS": "0", "LAPS": "12", "TIME": r"\N", "MILLISECONDS": r"\N", "FASTESTLAP": r"\N", "RANK": r"\N",
           "FASTESTLAPTIME": r"\N", "FASTESTLAPSPEED": r"\N", "STATUSID": "5"}
    for schema in (s["raw"], s["truth"]):
        run(conn, f"insert into {schema}.results ({', '.join(row)}) select {', '.join('%s' for _ in row)}",
            list(row.values()))


def orphan_driver(conn, s):
    """The reserve driver's record finally arrives."""
    row = {"DRIVERID": ORPHAN_DRIVER_ID, "DRIVERREF": "reserve", "NUMBER": "50", "CODE": "RES",
           "FORENAME": "Sam", "SURNAME": "Reserve", "DOB": "2003-05-01", "NATIONALITY": "British", "URL": r"\N"}
    for schema in (s["raw"], s["truth"]):
        run(conn, f"insert into {schema}.drivers ({', '.join(row)}) select {', '.join('%s' for _ in row)}",
            list(row.values()))


def drift_v2(conn, s):
    """Heavier vendor migration: column renames, a dropped column, a renamed table,
    a new date format, and a new null marker in qualifying."""
    drift(conn, s)
    raw = s["raw"]
    run(conn, f"alter table {raw}.lap_times rename to {raw}.lap_timing")
    run(conn, f"update {raw}.races set date = to_char(date::date, 'DD/MM/YYYY')")
    for col in ("q1", "q2", "q3"):
        run(conn, f"update {raw}.qualifying set {col} = '' where {col} = chr(92) || 'N'")


def dup_standings(conn, s):
    """The vendor resends standings for race 1142 with fresh ids."""
    raw = s["raw"]
    cols = [r[2] for r in run(conn, f"show columns in table {raw}.driver_standings")]
    sel = ", ".join("(driverstandingsid::int + 100000)::varchar" if c == "DRIVERSTANDINGSID" else c for c in cols)
    run(conn, f"insert into {raw}.driver_standings select {sel} from {raw}.driver_standings where raceid = '1142'")


def vendor_b(conn, s):
    """Second vendor feed for 2018-2024, generated from clean truth data into raw and truth."""
    vx.gen_vendor_b(conn, s["truth"], [s["raw"], s["truth"]], run)


def telemetry_initial(conn, s):
    """Telemetry minus the last race and a block of late samples (zero-copy clone, then delete)."""
    hold = CFG["SF_HOLDOUT_SCHEMA"]
    run(conn, f"create or replace table {s['raw']}.car_telemetry clone {hold}.car_telemetry")
    run(conn, f"delete from {s['raw']}.car_telemetry where {vx.LATE_OR_NEW}")
    run(conn, f"create or replace table {s['truth']}.car_telemetry clone {hold}.car_telemetry")


def telemetry_late(conn, s):
    """The last race's telemetry lands, plus samples from three weeks earlier, all loaded now."""
    hold = CFG["SF_HOLDOUT_SCHEMA"]
    cols = [r[2] for r in run(conn, f"show columns in table {hold}.car_telemetry")]
    sel = ", ".join("current_timestamp()::timestamp_ntz" if c == "_LOADED_AT" else c for c in cols)
    run(conn, f"insert into {s['raw']}.car_telemetry ({', '.join(cols)}) "
              f"select {sel} from {hold}.car_telemetry where {vx.LATE_OR_NEW}")


def prep_telemetry(conn, s):
    """One-time: generate the full telemetry table into the holdout schema (~20M rows)."""
    hold = CFG["SF_HOLDOUT_SCHEMA"]
    vx.gen_telemetry(conn, hold, hold, run)
    print(run(conn, f"select count(*) from {hold}.car_telemetry"))


STEPS = {
    "setup": setup,
    "arrive1": lambda c, s: arrive(c, s, 1),
    "arrive2": lambda c, s: arrive(c, s, 2),
    "correct_laps": correct_laps,
    "driver_change": driver_change,
    "drift": drift,
    "dup_constructor": dup_constructor,
    "orphan_result": orphan_result,
    "orphan_driver": orphan_driver,
    "drift_v2": drift_v2,
    "dup_standings": dup_standings,
    "vendor_b": vendor_b,
    "telemetry_initial": telemetry_initial,
    "telemetry_late": telemetry_late,
    "prep_telemetry": prep_telemetry,
    "teardown": teardown,
}

if __name__ == "__main__":
    run_id, step = sys.argv[1], sys.argv[2]
    conn = connect()
    STEPS[step](conn, run_schemas(run_id))
    print(f"[inject] {run_id}: {step} ok")
