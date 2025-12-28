"""Convert pimsleur tab file into clean.json with unit mapping."""

from __future__ import annotations

import csv
import json
import re
from pathlib import Path


INPUT_FILE = Path(__file__).with_name("pimsler2.txt")
OUTPUT_FILE = Path(__file__).with_name("clean.json")
MEDIA_FILE = Path(__file__).with_name("anki") / "media"

DECK_PATTERN = re.compile(r"Level\s+(\d+)::Lesson\s+(\d+)", re.IGNORECASE)
SOUND_PREFIX = "[sound:"


def compute_unit_number(deck_name: str) -> int | None:
    """Extract level/lesson and compute numeric unit value."""
    match = DECK_PATTERN.search(deck_name)
    if not match:
        return None
    level = int(match.group(1))
    lesson = int(match.group(2))
    return (level - 1) * 30 + lesson


def format_unit(unit_number: int) -> str:
    return f"Unit_{unit_number}"


def clean_audio(audio_field: str) -> str:
    """Strip [sound:...] wrapper if present."""
    audio_field = audio_field.strip()
    if audio_field.startswith(SOUND_PREFIX) and audio_field.endswith("]"):
        return audio_field[len(SOUND_PREFIX) : -1]
    return audio_field


def parse_rows(rows) -> list[dict]:
    """Parse tab-separated rows into cleaned dict objects."""
    cleaned = []
    for parts in rows:
        if len(parts) < 6:
            continue  # skip malformed rows

        deck_name = parts[2]
        english_phrase = parts[3]
        korean_phrase = parts[4]
        audio_field = parts[5]

        unit_number = compute_unit_number(deck_name)
        if unit_number is None:
            continue

        cleaned.append(
            {
                "unit": format_unit(unit_number),
                "unit_number": unit_number,  # keep numeric for sorting/filtering later
                "english_phrase": english_phrase,
                "korean_phrase": korean_phrase,
                "audio_path": clean_audio(audio_field),
            }
        )
    return cleaned


def main() -> None:
    if not INPUT_FILE.exists():
        raise FileNotFoundError(f"Missing input file: {INPUT_FILE}")
    if not MEDIA_FILE.exists():
        raise FileNotFoundError(f"Missing media file: {MEDIA_FILE}")

    # Load media mapping and reverse it: audio filename -> number
    media_map = json.loads(MEDIA_FILE.read_text(encoding="utf-8"))
    audio_to_number = {v: k for k, v in media_map.items()}

    with INPUT_FILE.open("r", encoding="utf-8", newline="") as f:
        for _ in range(6):  # skip metadata header lines
            next(f, None)
        reader = csv.reader(f, delimiter="\t")
        data = parse_rows(reader)

    # Filter to Unit_1..Unit_60 inclusive
    data = [row for row in data if row.get("unit_number", 0) <= 60]

    # Sort by unit number, preserving original order within each unit
    data.sort(key=lambda row: row.get("unit_number", 0))

    # Add incremental id and drop helper field
    for idx, row in enumerate(data, start=1):
        audio_filename = row.get("audio_path")
        mapped = audio_to_number.get(audio_filename)
        if mapped is not None:
            row["audio_path"] = f"{mapped}.mp3"
        row["id"] = idx
        row.pop("unit_number", None)

    OUTPUT_FILE.write_text(
        json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"Wrote {len(data)} entries to {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
