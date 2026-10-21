#!/usr/bin/env python3
"""Planificateur Meta officiel pour les Reels BoosterFish.

Le mode par défaut est une simulation. Une publication réelle exige --live.
Le journal SQLite rend chaque envoi idempotent par jour et par plateforme.
"""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime
from pathlib import Path
from typing import Any


AUTOMATION_DIR = Path(__file__).resolve().parent
PACK_DIR = AUTOMATION_DIR.parent
DEFAULT_SCHEDULE = AUTOMATION_DIR / "schedule.json"
DEFAULT_ENV = AUTOMATION_DIR / "meta.env"
DEFAULT_DB = AUTOMATION_DIR / "state/social_scheduler.sqlite3"


class ConfigError(RuntimeError):
    pass


class MetaAPIError(RuntimeError):
    pass


def load_env(path: Path) -> None:
    if not path.exists():
        return
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key, value = key.strip(), value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
            value = value[1:-1]
        os.environ.setdefault(key, value)


def env(name: str, required: bool = False) -> str:
    value = os.environ.get(name, "").strip()
    if required and (not value or value.startswith("REMPLACER_")):
        raise ConfigError(f"Variable manquante dans meta.env : {name}")
    return value


def load_schedule(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ConfigError(f"Calendrier introuvable : {path}") from exc
    except json.JSONDecodeError as exc:
        raise ConfigError(f"JSON invalide dans {path}: {exc}") from exc
    if not isinstance(data.get("posts"), list):
        raise ConfigError("schedule.json doit contenir une liste 'posts'.")
    return data


def public_video_url(post: dict[str, Any]) -> str:
    base = env("PUBLIC_MEDIA_BASE_URL", required=True).rstrip("/") + "/"
    path = urllib.parse.quote(str(post["public_video_path"]).lstrip("/"), safe="/")
    return urllib.parse.urljoin(base, path)


def validate(schedule: dict[str, Any], require_secrets: bool = False) -> list[str]:
    errors: list[str] = []
    seen_days: set[int] = set()
    seen_times: set[str] = set()
    valid_platforms = {"facebook", "instagram"}

    for post in schedule["posts"]:
        day = post.get("day")
        if not isinstance(day, int) or day < 1:
            errors.append(f"Jour invalide : {day!r}")
            continue
        if day in seen_days:
            errors.append(f"Jour en double : {day}")
        seen_days.add(day)

        try:
            publish_at = datetime.fromisoformat(post["publish_at"])
            if publish_at.tzinfo is None:
                errors.append(f"Jour {day}: publish_at doit inclure le fuseau horaire")
            if post["publish_at"] in seen_times:
                errors.append(f"Jour {day}: horaire en double")
            seen_times.add(post["publish_at"])
        except (KeyError, TypeError, ValueError):
            errors.append(f"Jour {day}: publish_at invalide")

        video = PACK_DIR / str(post.get("video", ""))
        cover = PACK_DIR / str(post.get("cover", ""))
        if not video.is_file():
            errors.append(f"Jour {day}: vidéo absente ({video})")
        elif video.suffix.lower() != ".mp4" or video.stat().st_size == 0:
            errors.append(f"Jour {day}: vidéo MP4 invalide ({video})")
        if not cover.is_file():
            errors.append(f"Jour {day}: couverture absente ({cover})")

        caption = str(post.get("caption", ""))
        if not caption.strip():
            errors.append(f"Jour {day}: légende vide")
        elif len(caption) > 2200:
            errors.append(f"Jour {day}: légende Instagram > 2 200 caractères")

        platforms = set(post.get("platforms", []))
        if not platforms or not platforms <= valid_platforms:
            errors.append(f"Jour {day}: plateformes invalides ({sorted(platforms)})")

    if require_secrets:
        for name in (
            "META_GRAPH_VERSION",
            "META_PAGE_ID",
            "META_IG_USER_ID",
            "META_PAGE_ACCESS_TOKEN",
            "PUBLIC_MEDIA_BASE_URL",
        ):
            try:
                env(name, required=True)
            except ConfigError as exc:
                errors.append(str(exc))
        version = os.environ.get("META_GRAPH_VERSION", "")
        if version and not version.startswith("v"):
            errors.append("META_GRAPH_VERSION doit ressembler à v26.0")

    return errors


class Journal:
    def __init__(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        self.db = sqlite3.connect(str(path))
        self.db.execute(
            """
            CREATE TABLE IF NOT EXISTS publications (
                day INTEGER NOT NULL,
                platform TEXT NOT NULL,
                status TEXT NOT NULL,
                remote_id TEXT,
                detail TEXT,
                updated_at TEXT NOT NULL,
                PRIMARY KEY (day, platform)
            )
            """
        )
        self.db.commit()

    def status(self, day: int, platform: str) -> str | None:
        row = self.db.execute(
            "SELECT status FROM publications WHERE day=? AND platform=?", (day, platform)
        ).fetchone()
        return row[0] if row else None

    def write(self, day: int, platform: str, status: str, remote_id: str = "", detail: str = "") -> None:
        self.db.execute(
            """
            INSERT INTO publications(day, platform, status, remote_id, detail, updated_at)
            VALUES(?, ?, ?, ?, ?, ?)
            ON CONFLICT(day, platform) DO UPDATE SET
              status=excluded.status,
              remote_id=excluded.remote_id,
              detail=excluded.detail,
              updated_at=excluded.updated_at
            """,
            (day, platform, status, remote_id, detail[:1000], datetime.now().astimezone().isoformat()),
        )
        self.db.commit()

    def rows(self) -> list[tuple[Any, ...]]:
        return self.db.execute(
            "SELECT day, platform, status, remote_id, detail, updated_at FROM publications ORDER BY day, platform"
        ).fetchall()


class MetaClient:
    def __init__(self) -> None:
        self.version = env("META_GRAPH_VERSION", required=True)
        self.page_id = env("META_PAGE_ID", required=True)
        self.ig_user_id = env("META_IG_USER_ID", required=True)
        self.token = env("META_PAGE_ACCESS_TOKEN", required=True)
        self.graph = f"https://graph.facebook.com/{self.version}"

    def request(
        self,
        method: str,
        url: str,
        params: dict[str, Any] | None = None,
        headers: dict[str, str] | None = None,
        raw_body: bytes | None = None,
    ) -> dict[str, Any]:
        request_headers = {
            "Authorization": f"Bearer {self.token}",
            "User-Agent": "BoosterFish-Social-Scheduler/1.0",
        }
        request_headers.update(headers or {})
        data = raw_body
        if params:
            encoded = urllib.parse.urlencode(params).encode("utf-8")
            if method.upper() == "GET":
                url += ("&" if "?" in url else "?") + encoded.decode("utf-8")
            else:
                data = encoded
                request_headers.setdefault("Content-Type", "application/x-www-form-urlencoded")
        request = urllib.request.Request(url, data=data, headers=request_headers, method=method.upper())
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                payload = response.read().decode("utf-8")
        except urllib.error.HTTPError as exc:
            payload = exc.read().decode("utf-8", errors="replace")
            try:
                parsed = json.loads(payload)
                message = parsed.get("error", {}).get("message", payload)
            except json.JSONDecodeError:
                message = payload
            raise MetaAPIError(f"Meta HTTP {exc.code}: {message}") from exc
        except urllib.error.URLError as exc:
            raise MetaAPIError(f"Réseau indisponible : {exc.reason}") from exc
        try:
            result = json.loads(payload)
        except json.JSONDecodeError as exc:
            raise MetaAPIError("Réponse Meta non JSON") from exc
        if "error" in result:
            raise MetaAPIError(str(result["error"].get("message", result["error"])))
        return result

    def publish_instagram(self, post: dict[str, Any]) -> str:
        create = self.request(
            "POST",
            f"{self.graph}/{self.ig_user_id}/media",
            {
                "media_type": "REELS",
                "video_url": public_video_url(post),
                "caption": post["caption"],
                "share_to_feed": "true" if post.get("share_to_feed", True) else "false",
            },
        )
        container_id = str(create.get("id", ""))
        if not container_id:
            raise MetaAPIError("Meta n'a pas renvoyé l'identifiant du conteneur Instagram")

        for _ in range(120):
            status = self.request(
                "GET",
                f"{self.graph}/{container_id}",
                {"fields": "status_code,status"},
            )
            code = status.get("status_code")
            if code == "FINISHED":
                break
            if code in {"ERROR", "EXPIRED"}:
                raise MetaAPIError(f"Traitement Instagram échoué : {status.get('status', code)}")
            time.sleep(5)
        else:
            raise MetaAPIError("Instagram n'a pas terminé le traitement dans les 10 minutes")

        published = self.request(
            "POST",
            f"{self.graph}/{self.ig_user_id}/media_publish",
            {"creation_id": container_id},
        )
        media_id = str(published.get("id", ""))
        if not media_id:
            raise MetaAPIError("Meta n'a pas renvoyé l'identifiant du Reel Instagram")
        return media_id

    def publish_facebook(self, post: dict[str, Any]) -> str:
        started = self.request(
            "POST",
            f"{self.graph}/{self.page_id}/video_reels",
            {"upload_phase": "start"},
        )
        video_id = str(started.get("video_id", ""))
        upload_url = str(started.get("upload_url", ""))
        if not video_id or not upload_url:
            raise MetaAPIError("Meta n'a pas renvoyé la session d'envoi Facebook")

        path = PACK_DIR / post["video"]
        payload = path.read_bytes()
        uploaded = self.request(
            "POST",
            upload_url,
            headers={
                "Authorization": f"OAuth {self.token}",
                "offset": "0",
                "file_size": str(len(payload)),
                "Content-Type": "application/octet-stream",
            },
            raw_body=payload,
        )
        if uploaded.get("success") is not True:
            raise MetaAPIError(f"Envoi Facebook non confirmé : {uploaded}")

        finished = self.request(
            "POST",
            f"{self.graph}/{self.page_id}/video_reels",
            {
                "upload_phase": "finish",
                "video_id": video_id,
                "video_state": "PUBLISHED",
                "description": post["caption"],
                "title": post["title"],
            },
        )
        if finished.get("success") is not True:
            raise MetaAPIError(f"Publication Facebook non confirmée : {finished}")
        return video_id


def publish_post(post: dict[str, Any], platforms: list[str], journal: Journal, live: bool) -> int:
    day = int(post["day"])
    if not live:
        print(f"[SIMULATION] Jour {day:02d} — {post['title']} — {', '.join(platforms)}")
        return 0

    client = MetaClient()
    failures = 0
    for platform in platforms:
        if journal.status(day, platform) == "published":
            print(f"[IGNORÉ] Jour {day:02d} déjà publié sur {platform}")
            continue
        journal.write(day, platform, "publishing", detail="Envoi démarré")
        try:
            remote_id = (
                client.publish_facebook(post)
                if platform == "facebook"
                else client.publish_instagram(post)
            )
            journal.write(day, platform, "published", remote_id=remote_id, detail="Publication confirmée")
            print(f"[PUBLIÉ] Jour {day:02d} sur {platform} — ID {remote_id}")
        except Exception as exc:  # Journaliser toute erreur sans bloquer l'autre réseau.
            failures += 1
            journal.write(day, platform, "failed", detail=str(exc))
            print(f"[ÉCHEC] Jour {day:02d} sur {platform} — {exc}", file=sys.stderr)
    return failures


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Planificateur Facebook/Instagram de BoosterFish")
    parser.add_argument("--schedule", type=Path, default=DEFAULT_SCHEDULE)
    parser.add_argument("--env", dest="env_file", type=Path, default=DEFAULT_ENV)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    sub = parser.add_subparsers(dest="command", required=True)

    validate_cmd = sub.add_parser("validate", help="Contrôler les fichiers et le calendrier")
    validate_cmd.add_argument("--require-secrets", action="store_true")
    sub.add_parser("plan", help="Afficher les 30 dates sans publier")
    sub.add_parser("status", help="Afficher le journal local")

    due = sub.add_parser("run-due", help="Publier les éléments arrivés à échéance")
    due.add_argument("--live", action="store_true", help="Autoriser réellement les publications")
    due.add_argument("--max-lateness-minutes", type=int, default=90)

    one = sub.add_parser("publish-day", help="Tester ou publier un jour précis")
    one.add_argument("--day", type=int, required=True)
    one.add_argument("--platform", choices=("facebook", "instagram", "both"), default="both")
    one.add_argument("--live", action="store_true", help="Autoriser réellement la publication")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    load_env(args.env_file)
    schedule = load_schedule(args.schedule)

    if args.command == "validate":
        errors = validate(schedule, require_secrets=args.require_secrets)
        if errors:
            for error in errors:
                print(f"ERREUR — {error}", file=sys.stderr)
            return 1
        print(f"OK — {len(schedule['posts'])} publications, médias et légendes valides")
        return 0

    errors = validate(schedule, require_secrets=getattr(args, "live", False))
    if errors:
        for error in errors:
            print(f"ERREUR — {error}", file=sys.stderr)
        return 1

    journal = Journal(args.db)
    if args.command == "plan":
        for post in schedule["posts"]:
            if post.get("enabled", True):
                print(f"J{post['day']:02d}  {post['publish_at']}  {post['title']}  ({', '.join(post['platforms'])})")
        return 0

    if args.command == "status":
        rows = journal.rows()
        if not rows:
            print("Aucune tentative de publication enregistrée.")
            return 0
        for day, platform, status, remote_id, detail, updated_at in rows:
            print(f"J{day:02d}  {platform:9}  {status:10}  {remote_id or '-':20}  {updated_at}  {detail or ''}")
        return 0

    if args.command == "publish-day":
        post = next((item for item in schedule["posts"] if item.get("day") == args.day), None)
        if post is None:
            print(f"Jour introuvable : {args.day}", file=sys.stderr)
            return 1
        platforms = post["platforms"] if args.platform == "both" else [args.platform]
        return 1 if publish_post(post, platforms, journal, args.live) else 0

    now = datetime.now().astimezone()
    failures = 0
    found = False
    for post in schedule["posts"]:
        if not post.get("enabled", True):
            continue
        planned = datetime.fromisoformat(post["publish_at"])
        delta_minutes = (now - planned).total_seconds() / 60
        if 0 <= delta_minutes <= args.max_lateness_minutes:
            found = True
            failures += publish_post(post, list(post["platforms"]), journal, args.live)
        elif delta_minutes > args.max_lateness_minutes:
            for platform in post["platforms"]:
                if journal.status(post["day"], platform) is None:
                    journal.write(post["day"], platform, "missed", detail="Créneau dépassé; publication manuelle requise")
    if not found:
        print("Aucune publication à envoyer dans le créneau courant.")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
