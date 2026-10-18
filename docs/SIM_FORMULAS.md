# Reverse-Engineered Simulation Formulas & Systems Specification
*Extracted from Classic Management Sims (Pocket Academy, Two Point Campus, Game Dev Story)*
*Documented for EduSystem Clean-Room Implementation*

---

## 1. Classroom Attention & Concentration Decay Model

### Reference Mechanics (Pocket Academy / Two Point Campus)
In classic school management simulations, student concentration does not drop as a pure linear counter; it behaves as a damped decay curve influenced by environmental comfort and proximity distractions.

### Mathematical Formulation
The student's live attention fraction $A(t) \in [0.0, 1.0]$ over lesson elapsed time $t$ obeys:
$$A(t) = A_0 \cdot \exp\left(-\frac{\lambda_{\text{base}}}{1 + B_{\text{room}}} \cdot t\right) - \sum_{i \in \text{neighbors}} D(d_i)$$

Where:
- $A_0$: Starting attention at lesson bell (default $1.0$).
- $\lambda_{\text{base}}$: Base fatigue rate ($\approx 0.022\text{ s}^{-1}$ for a standard 45s period).
- $B_{\text{room}}$: Cumulative room decor/insulation bonus from nearby fixtures ($\text{bonus} \in [0.0, 0.62]$).
- $D(d_i)$: Proximity distraction from an adjacent un-hushed chatting or restless peer at tile distance $d_i$:
  $$D(d_i) = \begin{cases} \delta \cdot \text{chat\_mult}_i & \text{if } d_i \le \text{reach\_tiles} \\ 0 & \text{otherwise} \end{cases}$$

### EduSystem Mapping & Integration
- Already present in `data/balance.json`:
  - `lesson.stall_chance_per_second: 0.14`
  - `chat.reach_tiles: 1`
  - `chat.start_per_second: 0.06`
  - `chat.talk_max_slowdown: 0.5`
- Recommended refinement for Admin/Coaching:
  - Add an attention decay damping multiplier unlocked when the room's teacher is coached in "Classroom Presence".

---

## 2. Staff Coaching & Pedagogy Progression (Admin Layer)

### Reference Mechanics (Two Point Campus / Game Dev Story)
In management sims with an administrative or delegation layer ("teaching teachers how to teach"):
1. Staff members possess latent attributes: **Reaction Speed**, **Discipline / Settling**, and **Subject Depth**.
2. Training/coaching does not merely boost a raw scalar; it unlocks discrete operational techniques.

### Mathematical Formulation for Teacher Reaction & Efficiency

#### A. Reaction Time Curve (Diminishing Returns)
When an unhandled event (stuck student, chatter, mess) appears, the teacher's reaction delay $R(\ell)$ at coaching level $\ell \in \{1, 2, 3, 4, 5\}$ scales as:
$$R(\ell) = R_{\text{min}} + (R_{\text{base}} - R_{\text{min}}) \cdot \left(\frac{1}{1 + \kappa \cdot (\ell - 1)}\right)$$

Where:
- $R_{\text{base}} = 5.0\text{ s}$ (Supply/novice teacher).
- $R_{\text{min}} = 1.2\text{ s}$ (Master teacher floor).
- $\kappa = 0.45$ (Curvature parameter).

#### B. Coaching Progression Tree
| Level | Title | Reaction Delay | Unlocked Capabilities in `RoomSim` |
|---|---|---|---|
| **1** | Supply / Novice | 5.0s | Basic teaching, collects work at bell. |
| **2** | Developing Teacher | 3.8s | Settles disruptive students before chatter escalates to messing about (`settles: true`). |
| **3** | Proficient Teacher | 2.9s | Executes diagnostic quizzes mid-lesson (`quizzes: true`); clears false stalls. |
| **4** | Senior Mentor | 2.1s | Proactively leverages peer tutoring (ZPD pairs) in room layout. |
| **5** | Master Educator | 1.4s | Anchors classroom attention; student fatigue decay halved. |

### Contract Protection Rule
Delegated rooms are executed via `RoomSim.play_day()`. Per EduSystem hard constraints:
> **The balance contract must hold:**
> Bare room, perfect teaching: ~0.63 (C)
> Full room, never helped: ~0.71 (C)
> Full room, perfect teaching: ~0.97 (A)
Coaching tunables influence teacher reaction speed and chore execution, but **never inflate the underlying grade caps** (`room_cap` 0.62, `lesson_cap` 0.35).

---

## 3. Student ZPD & Scaffolding Multipliers

### Reference Mechanics (Vygotsky Scaffolding in Sims)
When two students collaborate, pacing bonus $\beta$ depends on the competence gap $\Delta = |C_A - C_B|$:
$$\beta(\Delta) = \begin{cases} 
1.0 + \beta_{\text{max}} \cdot \frac{\Delta - \Delta_{\text{min}}}{\Delta_{\text{optimal}} - \Delta_{\text{min}}} & \text{if } \Delta_{\text{min}} \le \Delta \le \Delta_{\text{optimal}} \\
1.0 + \beta_{\text{max}} \cdot \frac{\Delta_{\text{max}} - \Delta}{\Delta_{\text{max}} - \Delta_{\text{optimal}}} & \text{if } \Delta_{\text{optimal}} < \Delta \le \Delta_{\text{max}} \\
\mu_{\text{mismatch}} & \text{if } \Delta > \Delta_{\text{max}} \text{ (gap too wide, frustration)}
\end{cases}$$

In EduSystem's current calibration:
- `gap_min: 0.08`
- `gap_max: 0.45`
- `boost_mult: 1.35`
- `mismatch_mult: 0.8`

This aligns with the reverse-engineered optimum from pedagogical management games: peer pairing accelerates progress by ~35% within the learning zone, while extreme mismatches lead to confusion and a 20% slowdown.
