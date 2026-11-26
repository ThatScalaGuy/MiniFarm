import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import summarize  # noqa: E402


class SummarizeTests(unittest.TestCase):
    def test_groups_samples_and_keeps_single_records(self):
        log = [
            'Test Case started.\n',
            'MINIFARM_PERF {"metric":"coldLaunch","scenario":"fresh","sample":0,"unit":"ms","operable":4000}\n',
            '    t =  12.3s MINIFARM_PERF {"metric":"coldLaunch","scenario":"fresh","sample":1,"unit":"ms","operable":5000}\n',
            'MINIFARM_PERF {"metric":"coldLaunch","scenario":"fresh","sample":2,"unit":"ms","operable":9000}\n',
            'MINIFARM_PERF {"metric":"placeSwitch","scenario":"qa","place":"loc.paddock","sample":0,"unit":"ms","operable":800}\n',
            'MINIFARM_PERF {"metric":"projection","unit":"us","median":4073}\n',
            'MINIFARM_PERF {not json}\n',
            '/x.swift:9: Test Case measured [Duration (ApplicationFirstFramePresentationResponsive), s] '
            'average: 3.5, relative standard deviation: 9%, values: [3.4, 3.6], baselineName: ""\n',
        ]
        summary, other = summarize.summarize(log)
        rows = {(row["metric"], row["place"], row["field"]): row for row in summary}
        cold = rows["coldLaunch", None, "operable"]
        self.assertEqual((cold["n"], cold["median"], cold["min"], cold["max"]), (3, 5000, 4000, 9000))
        self.assertEqual(rows["placeSwitch", "loc.paddock", "operable"]["n"], 1)
        self.assertEqual(rows["systemLaunch", None, "responsive"]["values"], [3400.0, 3600.0])
        self.assertEqual(other, [{"metric": "projection", "unit": "us", "median": 4073}])

    def test_empty_log_is_reported_as_failure(self):
        self.assertEqual(summarize.summarize(["no timings\n"]), ([], []))


if __name__ == "__main__":
    unittest.main()
