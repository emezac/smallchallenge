#!/usr/bin/env python3
import json
import sys
from pathlib import Path


def load(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def main():
    if len(sys.argv) != 4:
        raise SystemExit("usage: evaluator.py DATASET BEFORE AFTER")
    dataset, before, after = map(load, sys.argv[1:])
    ids = [case["case_id"] for case in dataset["cases"]]
    if len(ids) < 15 or len(ids) > 25 or len(ids) != len(set(ids)):
        raise SystemExit("invalid dataset size or duplicate case_id")
    results = {}
    for label, run in (("before", before), ("after", after)):
        run_ids = [item["case_id"] for item in run["results"]]
        if run_ids != ids:
            raise SystemExit(f"{label}: case order or membership differs from dataset")
        passed = sum(item["verdict"] == "pass" for item in run["results"])
        declared = run["case_success"]
        if [passed, len(run_ids)] != [declared["passed"], declared["total"]]:
            raise SystemExit(f"{label}: declared metric does not match results")
        results[label] = passed
    print(json.dumps({"total": len(ids), **results, "delta": results["after"] - results["before"]}))


if __name__ == "__main__":
    main()

