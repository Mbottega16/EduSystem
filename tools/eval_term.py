"""Headless Term Evaluator for EduSystem Director Bot Personas.

Runs N full terms across fixed or randomized seeds, aggregates gameplay metrics,
evaluates grade distributions and fitness, and reports persona performance.

Usage:
    python tools/eval_term.py --persona pedagogy_master --seeds 101,102,103 --speed 2.5
    python tools/eval_term.py --compare pedagogy_master steady_teacher --seeds 101,102
"""
import argparse
import os
import re
import subprocess
import sys
import tempfile
from collections import Counter


def get_godot_path(game_dir):
    pfile = os.path.join(game_dir, "tools", "godot_path.txt")
    if os.path.exists(pfile):
        with open(pfile, "r", encoding="utf-8") as f:
            return f.readline().strip()
    return "godot"


def run_term(game_dir, godot_path, seed, persona, game_seconds=600.0, speed=2.5):
    """Run one evaluation term headless and parse the stdout."""
    out_log = tempfile.NamedTemporaryFile(delete=False, suffix=".log")
    out_log.close()
    
    cmd = [
        godot_path,
        "--headless",
        "--path", game_dir,
        "res://tools/director.tscn",
        "--",
        str(seed),
        f"eval_{persona}_{seed}",
        f"Eval_{persona}",
        str(game_seconds),
        str(speed),
        persona
    ]
    
    try:
        with open(out_log.name, "w", encoding="utf-8") as f_out:
            proc = subprocess.run(
                cmd,
                stdout=f_out,
                stderr=subprocess.STDOUT,
                timeout=int(game_seconds * 4 / max(speed, 1.0) + 120),
                cwd=game_dir
            )
        
        with open(out_log.name, "r", encoding="utf-8", errors="ignore") as f_in:
            lines = f_in.readlines()
    except subprocess.TimeoutExpired:
        return {"error": "Timeout", "seed": seed, "persona": persona}
    finally:
        if os.path.exists(out_log.name):
            os.remove(out_log.name)
            
    stats = {
        "persona": persona,
        "seed": seed,
        "days": 0,
        "coins": 0,
        "grades": Counter(),
        "events": Counter(),
        "recoveries": 0,
        "stuck_days": 0,
        "items_bought": [],
        "skills_learned": [],
        "passed": False
    }
    
    grade_weights = {"A": 4.0, "B": 3.0, "C": 2.0, "D": 1.0, "E": 0.5, "F": 0.0}
    
    for line in lines:
        if "DIRECTOR" in line:
            parts = line.strip().split("|")
            if len(parts) >= 3:
                kind = parts[1].strip()
                text = parts[2].strip()
                stats["events"][kind] += 1
                if kind == "recover":
                    stats["recoveries"] += 1
                elif kind == "stuck":
                    stats["stuck_days"] += 1
                elif kind == "buy":
                    stats["items_bought"].append(text)
                elif kind == "skill":
                    stats["skills_learned"].append(text)
                elif kind == "day":
                    m = re.search(r"now day (\d+), coins (\d+), class ([A-F])", text)
                    if m:
                        stats["days"] = max(stats["days"], int(m.group(1)))
                        stats["coins"] = int(m.group(2))
                        stats["grades"][m.group(3)] += 1
        if "DIRECTOR DONE" in line:
            stats["passed"] = True
            m = re.search(r"day=(\d+)", line)
            if m:
                stats["days"] = max(stats["days"], int(m.group(1)))

    total_graded = sum(stats["grades"].values())
    if total_graded > 0:
        stats["gpa"] = sum(stats["grades"][g] * grade_weights.get(g, 0) for g in stats["grades"]) / total_graded
    else:
        stats["gpa"] = 0.0
        
    return stats


def main():
    parser = argparse.ArgumentParser(description="Evaluate Director Bot Personas")
    parser.add_argument("--game", default=os.path.abspath("."))
    parser.add_argument("--persona", default="pedagogy_master")
    parser.add_argument("--compare", nargs="+", help="Compare multiple personas")
    parser.add_argument("--seeds", default="1001,1002", help="Comma-separated seed list")
    parser.add_argument("--seconds", type=float, default=300.0, help="Simulated game seconds")
    parser.add_argument("--speed", type=float, default=2.5, help="Simulation time scale speed")
    args = parser.parse_args()

    godot = get_godot_path(args.game)
    seeds = [int(s.strip()) for s in args.seeds.split(",") if s.strip()]
    personas = args.compare if args.compare else [args.persona]

    print("=" * 60)
    print("EduSystem Autonomous Persona Evaluator")
    print(f"Godot:    {godot}")
    print(f"Personas: {personas}")
    print(f"Seeds:    {seeds}")
    print(f"Speed:    {args.speed}x")
    print("=" * 60)

    for p in personas:
        print(f"\nEvaluating Persona: [{p}]")
        results = []
        for s in seeds:
            print(f"  Running seed {s}...", end="", flush=True)
            res = run_term(args.game, godot, s, p, game_seconds=args.seconds, speed=args.speed)
            if "error" in res:
                print(f" FAILED ({res['error']})")
            else:
                print(f" DONE: {res['days']} days, GPA: {res['gpa']:.2f}, Grades: {dict(res['grades'])}, Recoveries: {res['recoveries']}")
                results.append(res)
                
        if results:
            avg_gpa = sum(r["gpa"] for r in results) / len(results)
            avg_coins = sum(r["coins"] for r in results) / len(results)
            tot_recoveries = sum(r["recoveries"] for r in results)
            all_grades = Counter()
            for r in results:
                all_grades.update(r["grades"])
                
            print(f"\n--- Summary for [{p}] ---")
            print(f"Average GPA:          {avg_gpa:.2f} / 4.0")
            print(f"Total Grade Counts:   {dict(all_grades)}")
            print(f"Average Ending Coins: {avg_coins:.1f}")
            print(f"Total Stuck Recoveries: {tot_recoveries}")


if __name__ == "__main__":
    main()
