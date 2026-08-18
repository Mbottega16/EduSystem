---
description: Full project-status report in the user's custom Deep Scan template — health, active tasks, blockers, risks, next directives
---

Produce a full project-status report for PixelRoom, filled in **honestly
from real project state**. Read the actual code and data, run the
verification tools, and use real conversation history. Never hallucinate
completed work, never hide uncertainty, never fabricate data. If a section
has nothing to report, write "None detected" / "No active blockers"
rather than inventing content. Route open decisions into the "Questions
for the User" section rather than interrupting mid-report.

**Gather real state before writing a word.** At minimum:

```
Run Tests.bat            assertion count — read the COUNT, not the word PASSED
Simulate a Term.bat      the three contract rows
python tools/check_docs.py
git log --oneline -15
```

Run `Audit the Room.bat` or `Trace a Day.bat` too if the report touches
what the buttons offer or how a day plays. A claim about the running game
that came from reading code is not evidence — this project has been burned
three times that way, and every instance is recorded in `CLAUDE.md`.

Use exactly this structure, in this order:

1. **🔴 Deep Scan** header (title line)
2. **Overall Status** — health / milestone / percent-complete
3. **Executive Summary** — up to 10 bullets
4. **Last Submission Analysis** — deliverables, improvements, alterations, unfinished work, confidence %, regression risks
5. **Progress Since Previous Report**
6. **Current Active Tasks** (table)
7. **Completed Tasks Archive**
8. **Blockers**
9. **Error Intelligence** (table)
10. **Technical Debt**
11. **Missing Pieces**
12. **Project Memory**
13. **Continuity Check**
14. **Risk Assessment** — top 5
15. **Next Directives** — top 10 (table)
16. **Recommended Immediate Action**
17. **Optimization Opportunities**
18. **Questions for the User**
19. **End-of-Report Metrics** — 8 numeric scores

$ARGUMENTS
