#!/usr/bin/env python3
"""Regenerate the importable weekly CSVs from the app's bundled course sample."""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
content = json.loads((ROOT / "Flashcards/Resources/theory-of-computation.json").read_text())
destination = ROOT / "SampleFiles/TheoryOfComputation"
destination.mkdir(parents=True, exist_ok=True)

for index, week in enumerate(content["weeks"], 1):
    path = destination / f"IN3017-week-{index}.csv"
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(["front", "back"])
        writer.writerows((card["front"], card["back"]) for card in week["cards"])
    print(f"{path.relative_to(ROOT)}: {len(week['cards'])} cards")
