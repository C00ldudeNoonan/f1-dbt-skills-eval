"""Load the Kaggle F1 CSVs into Snowflake.

usage: uv run --with 'snowflake-connector-python[pandas]' scripts/load_raw.py data/f1

Everything lands as VARCHAR on purpose: the CSVs use the literal string \\N for nulls,
and casting/cleaning is part of what the agent has to figure out.

Creates:
  SF_HOLDOUT_SCHEMA   full dataset (injector source only)
  SF_PRISTINE_SCHEMA  starting state: the last HOLDOUT_RACES completed races of the latest
                      season keep their RACES calendar rows but lose all results/laps/stops
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "harness"))

import pandas as pd
from snowflake.connector.pandas_tools import write_pandas

from sf import CFG, connect, run

RACE_TABLES = [
    "RESULTS", "SPRINT_RESULTS", "LAP_TIMES", "PIT_STOPS", "QUALIFYING",
    "DRIVER_STANDINGS", "CONSTRUCTOR_STANDINGS", "CONSTRUCTOR_RESULTS",
]


def main(csv_dir: Path):
    holdout, pristine = CFG["SF_HOLDOUT_SCHEMA"], CFG["SF_PRISTINE_SCHEMA"]
    n = int(CFG["HOLDOUT_RACES"])
    conn = connect()
    run(conn, f"create or replace schema {holdout}")
    run(conn, f"use schema {holdout}")

    for f in sorted(csv_dir.glob("*.csv")):
        table = f.stem.upper()
        df = pd.read_csv(f, dtype=str, keep_default_na=False, encoding="utf-8")
        df.columns = [c.upper() for c in df.columns]
        write_pandas(conn, df, table, auto_create_table=True, overwrite=True, quote_identifiers=False)
        print(f"loaded {table}: {len(df):,} rows, cols={list(df.columns)}")

    held = run(conn, f"""
        with done as (
          select ra.raceid, ra.year::int yr, ra.round::int rnd
          from {holdout}.races ra
          where exists (select 1 from {holdout}.results r where r.raceid = ra.raceid)
        )
        select raceid from done
        where yr = (select max(yr) from done)
        qualify row_number() over (order by rnd desc) <= {n}
        order by rnd
    """)
    held_ids = [r[0] for r in held]
    print(f"holding out raceIds (in arrival order): {held_ids}")

    run(conn, f"create or replace schema {pristine} clone {holdout}")
    ids = ",".join(f"'{i}'" for i in held_ids)
    existing = {r[1] for r in run(conn, f"show tables in schema {pristine}")}
    for t in RACE_TABLES:
        if t in existing:
            run(conn, f"delete from {pristine}.{t} where raceid in ({ids})")
    run(conn, f"create or replace table {holdout}._HELD_RACES (raceid varchar, arrival int)")
    for i, rid in enumerate(held_ids, 1):
        run(conn, f"insert into {holdout}._HELD_RACES values ('{rid}', {i})")
    print("done")


if __name__ == "__main__":
    main(Path(sys.argv[1]))
