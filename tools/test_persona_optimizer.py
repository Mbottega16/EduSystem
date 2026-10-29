#!/usr/bin/env python3
"""Fixture test for the persona optimizer's report numbers.

Run: python3 tools/test_persona_optimizer.py
Feeds tools/fixtures/persona_runs.jsonl through analyze_telemetry() and
generate_report(), then checks the Chore Fixation line against the scores it prints.
"""
import os
import re
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import persona_optimizer as po  # noqa: E402

FIXTURE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fixtures", "persona_runs.jsonl")
CHORE_LINE = re.compile(
    r"average \*\*([\d.]+) pts\*\* vs \*\*([\d.]+) pts\*\*.*?\*\*([+-][\d.]+) pt gap\*\*"
)


def report_for(runs):
    with tempfile.TemporaryDirectory() as tmp:
        out = os.path.join(tmp, "report.md")
        po.generate_report(po.analyze_telemetry(runs), None, out)
        with open(out, "r", encoding="utf-8") as f:
            return f.read()


class ChoreFixationReportTest(unittest.TestCase):
    def setUp(self):
        self.runs = po.load_telemetry(FIXTURE)

    def test_fixture_loads_all_runs(self):
        self.assertEqual(len(self.runs), 6)

    def test_delta_equals_difference_of_printed_scores(self):
        report = report_for(self.runs)
        m = CHORE_LINE.search(report)
        self.assertIsNotNone(m, "Chore Fixation line missing or reformatted")
        teaching, chores, gap = (float(x) for x in m.groups())
        # teaching-first avg (50, 60, 71) = 60.3; chores-first avg (20, 30, 40) = 30.0
        self.assertEqual(teaching, 60.3)
        self.assertEqual(chores, 30.0)
        self.assertEqual(gap, 30.3)
        self.assertEqual(round(teaching - chores, 1), gap)

    def test_empty_group_reports_no_comparison(self):
        teaching_only = [r for r in self.runs if r["persona_params"]["chores_first"] is False]
        report = report_for(teaching_only)
        self.assertIn("No comparison yet", report)
        self.assertIn("3 runs with `chores_first=False`", report)
        self.assertIn("0 runs with `chores_first=True`", report)
        self.assertNotIn("pt gap", report)
        self.assertNotIn("0.0 pts", report)

    def test_chores_impact_keeps_none_for_empty_group(self):
        teaching_only = [r for r in self.runs if r["persona_params"]["chores_first"] is False]
        impact = po.analyze_telemetry(teaching_only)["chores_impact"]
        self.assertIsNone(impact["chores_first_avg"])
        self.assertIsNone(impact["delta"])
        self.assertEqual(impact["teaching_first_runs"], 3)


if __name__ == "__main__":
    unittest.main()
