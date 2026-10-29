# EduSystem Autonomous Bot Fleet Telemetry & Learning Report

*Generated: 2026-10-29 12:03:07* | Total Runs Analyzed: **1288**

---

## 1. Day-over-Day Learning Curve
| Date | Runs | Avg Score | Best Score | Avg GPA | Avg Coins | Max Term | Grade Mix |
|---|---|---|---|---|---|---|---|
| **2026-10-27** | 376 | 25.4/100 | 41 | 0.89 / 4.0 | 65 | Term 1 | `C:26 D:222 E:120 F:8` |
| **2026-10-28** | 912 | 39.8/100 | 68 | 1.72 / 4.0 | 65 | Term 3 | `A:2 B:62 C:556 D:237 E:55` |

## 2. Persona Skill Tier Performance Leaderboard
| Persona | Tier | Runs | Avg Score | Peak Score | Avg GPA | Avg Helps | Avg Messes | Grade Mix |
|---|---|---|---|---|---|---|---|---|
| **furniture_nerd** | Tier 3 | 300 | **45.0** | 68 | 2.15 | 4.9 | 2.4 | `A:1 B:55 C:232 D:11 E:1` |
| **pedagogy_master** | Tier 4 | 485 | **36.3** | 58 | 1.47 | 30.8 | 9.0 | `B:6 C:253 D:157 E:65 F:4` |
| **steady_teacher** | Tier 3 | 503 | **29.3** | 62 | 1.09 | 38.2 | 11.8 | `A:1 B:1 C:97 D:291 E:109 F:4` |

## 3. Telemetry Parameter Correlations with Student Outcomes
| Behavioral Dial | Pearson Correlation (r) | Correlation Impact | Pedagogical Recommendation |
|---|---|---|---|
| `reaction_delay` | `-0.228` | **Moderate Negative (-)** | Keep low (< 0.2s); delayed response starves stuck children and causes attention cascading. |
| `chain_radius` | `+0.357` | **Moderate Positive (+)** | Keep between 4.0-4.8 tiles; allows multi-desk assistance before returning to podium. |
| `max_chain_count` | `+0.052` | **Neutral (~0)** | Optimal at 2; chaining >3 desks starves front lecture time. |
| `quiz_frequency_days` | `+0.052` | **Neutral (~0)** | Optimal every 2-3 days; 1-day quizzes over-consume lesson time. |
| `min_coins_buffer` | `-0.545` | **Strong Negative (-)** | Maintain 20-30 coins; ensures liquidity while investing in high-aura room decor. |

> [!IMPORTANT]
> **Chore Fixation Penalty:** No comparison yet. 1288 runs with `chores_first=False` and 0 runs with `chores_first=True`, so neither the teaching-first nor the chores-first average can be compared. Addressing stuck desks must always take precedence over floor sweeping.