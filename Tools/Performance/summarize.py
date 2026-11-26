#!/usr/bin/env python3
"""Condense `MINIFARM_PERF {json}` lines from measure.sh logs into medians and ranges.

Records carrying a `sample` index are raw timings and get aggregated per metric, scenario and place.
Every other record (size, projection, context) is reported unchanged. Apple's
XCTApplicationLaunchMetric line is picked up as metric `systemLaunch`.
"""
import json
import re
import statistics
import sys

PREFIX = "MINIFARM_PERF "
LAUNCH = re.compile(r"measured \[Duration \(ApplicationFirstFramePresentationResponsive\), s\].*?values: \[([^\]]*)\]")


def records(lines):
    for line in lines:
        if PREFIX in line:
            text = line.split(PREFIX, 1)[1].strip()
            try:
                record = json.loads(text)
            except ValueError:
                continue
            if isinstance(record, dict) and isinstance(record.get("metric"), str):
                yield record
        elif match := LAUNCH.search(line):
            for index, value in enumerate(match.group(1).split(",")):
                yield {"metric": "systemLaunch", "scenario": "qa", "sample": index, "unit": "ms",
                       "responsive": round(float(value) * 1000, 1)}


def summarize(lines):
    groups, other = {}, []
    for record in records(lines):
        if "sample" not in record:
            other.append(record)
            continue
        key = tuple(record.get(name) for name in ("metric", "scenario", "place"))
        group = groups.setdefault(key, {"unit": record.get("unit"), "values": {}})
        for name, value in record.items():
            if name not in ("sample", "metric", "scenario", "place", "unit") and isinstance(value, (int, float)):
                group["values"].setdefault(name, []).append(float(value))
    summary = []
    for (metric, scenario, place), group in groups.items():
        for name, values in group["values"].items():
            summary.append({"metric": metric, "scenario": scenario, "place": place, "field": name,
                            "unit": group["unit"], "n": len(values), "median": round(statistics.median(values), 1),
                            "min": round(min(values), 1), "max": round(max(values), 1), "values": values})
    return summary, other


def main(paths):
    lines = []
    for path in paths:
        with open(path, encoding="utf-8", errors="replace") as handle:
            lines.extend(handle)
    summary, other = summarize(lines)
    for record in other:
        print(json.dumps(record, sort_keys=True, ensure_ascii=False))
    for row in summary:
        where = "/".join(part for part in (row["scenario"], row["place"]) if part)
        print(f"{row['metric']:<14} {where:<18} {row['field']:<15} n={row['n']:<3} "
              f"median={row['median']:>9} {row['unit']}  min={row['min']}  max={row['max']}")
    return 0 if summary or other else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
