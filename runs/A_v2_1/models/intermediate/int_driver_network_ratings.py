"""
Driver pace ratings on one scale from same-car (teammate) comparisons.

For each signal (qualifying, race_pace), solves the weighted least-squares
problem

    rating[d] - rating[t] = mean_gap_pct(d, t)      for every teammate pair,
    weight = number of comparisons,

subject to: within each connected group of drivers (linked by having been
teammates, directly or through others), the comparison-weighted average
rating is 0. A rating is therefore "% of lap time versus the average driver
in the same car", corrected for teammate strength transitively: beating a fast
teammate counts for more than beating a slow one.

Standard errors come from the constrained estimator's covariance,
sigma^2 * [KKT^-1] (top-left block), with sigma^2 the pooled within-pair
variance of single-race gaps, so uncertainty in teammates' ratings propagates.

Ratings are only comparable within a connected group; is_main_component
marks the largest one (almost every driver since 1994).
"""
import numpy as np
import pandas as pd


def _components(n, edges):
    parent = list(range(n))

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    for a, b in edges:
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[ra] = rb
    return [find(i) for i in range(n)]


def _solve(df):
    # One equation per unordered pair.
    df = df[df["DRIVER_ID"] < df["TEAMMATE_ID"]].reset_index(drop=True)
    drivers = np.unique(np.concatenate([df["DRIVER_ID"].values, df["TEAMMATE_ID"].values]))
    index = {d: i for i, d in enumerate(drivers)}
    n, m = len(drivers), len(df)
    rows = np.arange(m)
    a_idx = df["DRIVER_ID"].map(index).values
    b_idx = df["TEAMMATE_ID"].map(index).values

    design = np.zeros((m, n))
    design[rows, a_idx] = 1.0
    design[rows, b_idx] = -1.0
    weights = df["COMPARISONS"].values.astype(float)
    target = df["MEAN_GAP_PCT"].values.astype(float)

    normal = design.T @ (weights[:, None] * design)
    rhs = design.T @ (weights * target)

    # Driver weight = total comparisons; one centring constraint per component.
    driver_weight = np.zeros(n)
    np.add.at(driver_weight, a_idx, weights)
    np.add.at(driver_weight, b_idx, weights)
    component = _components(n, zip(a_idx, b_idx))
    roots = sorted(set(component))
    constraints = np.zeros((len(roots), n))
    for k, root in enumerate(roots):
        members = [i for i in range(n) if component[i] == root]
        constraints[k, members] = driver_weight[members] / driver_weight[members].sum()

    c = len(roots)
    kkt = np.block([[normal, constraints.T], [constraints, np.zeros((c, c))]])
    kkt_inv = np.linalg.pinv(kkt)
    solution = kkt_inv @ np.concatenate([rhs, np.zeros(c)])
    ratings = solution[:n]

    # Pooled variance of single comparisons: within-pair spread plus misfit of pair means.
    residual = target - design @ ratings
    total_comparisons = weights.sum()
    within = df["SUM_SQ_DEV"].values.sum()
    between = (weights * residual ** 2).sum()
    dof = max(total_comparisons - (n - c), 1.0)
    sigma2 = (within + between) / dof
    se = np.sqrt(np.clip(np.diag(kkt_inv[:n, :n]) * sigma2, 0, None))

    sizes = pd.Series(component).value_counts()
    main_root = sizes.idxmax()
    return pd.DataFrame({
        "DRIVER_ID": drivers.astype(int),
        "RATING_PCT": ratings,
        "RATING_SE_PCT": se,
        # Identify each group by its lowest driver_id, which is stable across runs.
        "COMPONENT_ID": [int(drivers[[i for i in range(n) if component[i] == r]].min()) for r in component],
        "COMPONENT_SIZE": [int(sizes[r]) for r in component],
        "IS_MAIN_COMPONENT": [r == main_root for r in component],
        "SIGMA_PCT": np.sqrt(sigma2),
    })


def model(dbt, session):
    dbt.config(materialized="table", packages=["numpy", "pandas"])
    pairs = dbt.ref("int_driver_teammate_pairs").to_pandas()
    frames = []
    for signal, df in pairs.groupby("SIGNAL"):
        result = _solve(df)
        result.insert(0, "SIGNAL", signal)
        frames.append(result)
    return session.create_dataframe(pd.concat(frames, ignore_index=True))
