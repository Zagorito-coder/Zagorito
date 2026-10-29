#!/usr/bin/env python3
"""Construit le calendrier d'automatisation à partir des 30 publications."""

from __future__ import annotations

import argparse
import json
from datetime import date, datetime, time, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo


AUTOMATION_DIR = Path(__file__).resolve().parent
PACK_DIR = AUTOMATION_DIR.parent


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--start", default="2026-10-01", help="Date du jour 1 (AAAA-MM-JJ)")
    parser.add_argument("--time", default="19:30", help="Heure locale quotidienne (HH:MM)")
    parser.add_argument("--timezone", default="Africa/Casablanca")
    parser.add_argument("--output", type=Path, default=AUTOMATION_DIR / "schedule.json")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    start = date.fromisoformat(args.start)
    hour, minute = map(int, args.time.split(":"))
    timezone = ZoneInfo(args.timezone)
    posts = json.loads((PACK_DIR / "content/posts.json").read_text(encoding="utf-8"))

    schedule = {
        "timezone": args.timezone,
        "generated_at": datetime.now(timezone).isoformat(timespec="seconds"),
        "notes": "Modifier publish_at si nécessaire. L'ordre éditorial reste celui du livrable validé.",
        "posts": [],
    }

    for post in posts:
        day = int(post["day"])
        slug = post["slug"]
        filename = f"{day:02d}_{slug}.mp4"
        publish_at = datetime.combine(start + timedelta(days=day - 1), time(hour, minute), timezone)
        caption = f"{post['caption']}\n\n{post['cta']}\n\n{post['hashtags']}"
        schedule["posts"].append(
            {
                "day": day,
                "slug": slug,
                "enabled": True,
                "publish_at": publish_at.isoformat(timespec="minutes"),
                "platforms": ["facebook", "instagram"],
                "title": post["series"],
                "caption": caption,
                "video": f"exports/reels/{filename}",
                "cover": f"exports/covers/{day:02d}_{slug}.png",
                "public_video_path": filename,
                "share_to_feed": True,
            }
        )

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(schedule, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Calendrier créé : {args.output} ({len(schedule['posts'])} publications)")


if __name__ == "__main__":
    main()
