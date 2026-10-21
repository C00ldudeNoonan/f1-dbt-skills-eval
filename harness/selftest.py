"""Validate the answer keys before trusting any grades.

usage: selftest.py   (run after scripts/load_raw.py)

1. Sanity-checks the answer keys against known F1 history, run on the full holdout data.
2. Materializes every answer key into a scratch schema as a fake "agent output" and grades
   it, which must score 100%. This proves the comparison logic itself is sound.
"""
from grade import (CHECKS, ak_alt_points, ak_dim_drivers, ak_fct_results, ak_qualifying, ak_season_standings,
                   ak_stints, ak_teammates, compare)
from sf import CFG, connect, run
import v2_extras as vx

H = CFG["SF_HOLDOUT_SCHEMA"]
SCRATCH = "ZZ_F1EVAL_SELFTEST"      # answer keys materialized as fake agent output
SRC = "ZZ_F1EVAL_SELFTEST_SRC"      # clone of holdout + generated vendor-B feed

FACTS = [
    # Hamilton and Schumacher each have 7 titles
    (f"select world_championships from ({ak_dim_drivers(H)}) where driver_ref = 'hamilton'", 7),
    (f"select world_championships from ({ak_dim_drivers(H)}) where driver_ref = 'michael_schumacher'", 7),
    # 1988: Prost outscored Senna on raw points (105 vs 94) but Senna won on best-11 results (90 vs 87)
    (f"""select d.driverref from ({ak_season_standings(H)}) s join {H}.drivers d on d.driverid::int = s.driver_id
         where season = 1988 and championship_position = 1""", "senna"),
    (f"""select sum(points) from ({ak_fct_results(H)}) f join {H}.drivers d on d.driverid::int = f.driver_id
         where season = 1988 and d.driverref = 'prost'""", 105),
    # v2: under 25-18-15 scoring Prost (7 wins, 7 seconds) beats Senna in 1988
    (f"""select d.driverref from ({ak_alt_points(H)}) a join {H}.drivers d on d.driverid::int = a.driver_id
         where season = 1988 and alt_position = 1""", "prost"),
    # v2: Hamilton and Rosberg raced together all 21 rounds of 2016
    (f"""select races_together from ({ak_teammates(H)}) t join {H}.drivers d on d.driverid::int = t.driver_id
         join {H}.drivers m on m.driverid::int = t.teammate_id
         where season = 2016 and d.driverref = 'hamilton' and m.driverref = 'rosberg'""", 21),
    # v2: every driver's stints add up to their laps, and pole has zero gap
    (f"""select count(*) from (select race_id, driver_id, sum(stint_laps) n, max(end_lap) m from ({ak_stints(H)})
         group by 1, 2 having n <> m)""", 0),
    (f"select count(*) from ({ak_qualifying(H)}) where gap_to_pole_ms = 0 and gap_to_pole_pct <> 0", 0),
    # Verstappen won 19 Grands Prix in 2023
    (f"""select sum(is_win) from ({ak_fct_results(H)}) f join {H}.drivers d on d.driverid::int = f.driver_id
         where season = 2023 and d.driverref = 'max_verstappen'""", 19),
]


def main():
    conn = connect()
    ok = True
    for sql, expected in FACTS:
        got = run(conn, sql)[0][0]
        good = str(got).rstrip("0").rstrip(".") == str(expected) or got == expected
        ok &= good
        print(f"{'PASS' if good else 'FAIL'}  expected {expected!r} got {got!r}")

    run(conn, f"create or replace schema {SRC} clone {H}")
    vx.gen_vendor_b(conn, SRC, [SRC], run)
    vb_facts = [
        (f"select count(*) from ({vx.ak_driver_crosswalk(SRC)})", run(conn, f"select count(*) from {SRC}.vb_drivers")[0][0]),
        (f"select count(*) from ({vx.ak_driver_crosswalk(SRC)}) where driver_id is null", 0),
        (f"select count(*) from ({vx.ak_discrepancies(SRC)}) where discrepancy_type = 'missing_in_vendor_b'", 3),
        (f"select count(*) from ({vx.ak_discrepancies(SRC)}) where discrepancy_type = 'points'", 4),
        (f"select count(*) from ({vx.ak_discrepancies(SRC)}) where discrepancy_type = 'position'", 4),
        (f"select count(*) from ({vx.ak_discrepancies(SRC)}) where discrepancy_type = 'missing_in_vendor_a'", 0),
        (f"select count(*) from {SRC}.vb_sessions where meeting_name = 'Spielberg' and year = 2020", 2),
        (f"select sum(samples) from ({vx.ak_lap_telemetry(SRC)})", run(conn, f"select count(*) from {SRC}.car_telemetry")[0][0]),
    ]
    for sql, expected in vb_facts:
        got = run(conn, sql)[0][0]
        ok &= got == expected
        print(f"{'PASS' if got == expected else 'FAIL'}  expected {expected!r} got {got!r}  [{sql[:60]}...]")

    run(conn, f"create or replace schema {SCRATCH}")
    for name, spec in CHECKS.items():
        run(conn, f"create or replace table {SCRATCH}.{name} as {spec['sql'](SRC)}")
        res = compare(conn, f"{CFG['SF_DATABASE']}.{SCRATCH}.{name}", spec["sql"](SRC), spec["keys"], spec["cols"])
        ok &= res["ok"]
        print(f"{'PASS' if res['ok'] else 'FAIL'}  self-compare {name}: {res['expected_rows']} rows "
              f"{'' if res['ok'] else res}")
    run(conn, f"drop schema {SCRATCH}")
    run(conn, f"drop schema {SRC}")
    print("\nALL GOOD" if ok else "\nSOME CHECKS FAILED: fix the answer keys before running agents")


if __name__ == "__main__":
    main()
