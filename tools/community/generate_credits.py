#!/usr/bin/env python3
"""Build the bundled Duels Reimagined credits from reviewed GitHub activity.

This tool runs on a developer machine or in GitHub Actions, never inside WoW.
It fails rather than silently replacing verified credits on API errors.
"""

from __future__ import annotations

import argparse
from collections import Counter
import json
import os
from pathlib import Path
import re
import sys
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[2]
CONFIG = ROOT / "community" / "credits.json"
OUTPUT = ROOT / "addon" / "DuelsReimagined" / "Community" / "Credits.lua"
DEFAULT_REPO = "HandiMain/wow-duels-reimagined"
BAD_LABELS = {"duplicate", "invalid", "wontfix", "wont-fix", "stale", "needs-info", "not-planned"}
MAX_PAGES = 30


def safe_display(value: str) -> str:
    if not isinstance(value, str) or not value.strip() or len(value) > 96:
        raise ValueError("Invalid credit display name (empty or over 96 characters)")
    name = value.strip()
    if any(ord(ch) < 32 or ord(ch) == 127 for ch in name):
        raise ValueError("Credit names cannot contain control characters")
    return name


def config_load(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    for key, expected in (("aliases", dict), ("exclude", list),
                          ("special_thanks", list), ("ideas", list)):
        if not isinstance(data.get(key), expected):
            raise ValueError(f"{path}: {key} must be {expected.__name__}")
    for login, display in data["aliases"].items():
        safe_display(login)
        safe_display(display)
    for value in data["exclude"] + data["special_thanks"]:
        safe_display(value)
    for item in data["ideas"]:
        if not isinstance(item, dict) or set(item) != {"name", "ref"}:
            raise ValueError("Each idea must have exactly a name and an issue/PR ref")
        safe_display(item["name"])
        if type(item["ref"]) is not int or item["ref"] <= 0:
            raise ValueError("Idea ref must be a positive integer")
    return data


def github_pages(repo: str, resource: str, token: str) -> list[dict]:
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repo):
        raise ValueError("Invalid repository")
    if resource not in ("issues", "pulls"):
        raise ValueError("Unsupported GitHub resource")
    if not token:
        raise ValueError("GITHUB_TOKEN is needed for live GitHub credits")
    output = []
    for page in range(1, MAX_PAGES + 1):
        url = (f"https://api.github.com/repos/{repo}/{resource}"
               f"?state=all&per_page=100&page={page}")
        req = Request(url, headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "duels-reimagined-community-credits",
        })
        try:
            with urlopen(req, timeout=20) as response:
                part = json.load(response)
        except (HTTPError, URLError, TimeoutError) as exc:
            raise RuntimeError(f"GitHub fetch failed for {resource} page {page}: {exc}") from exc
        if not isinstance(part, list):
            raise RuntimeError(f"Unexpected GitHub response for {resource} page {page}")
        output.extend(part)
        if len(part) < 100:
            return output
    raise RuntimeError(f"GitHub pagination exceeded {MAX_PAGES} pages; refusing incomplete credits")


def render_lua_string(value: str) -> str:
    name = safe_display(value)
    escapes = {"\\": "\\\\", '"': '\\"'}
    return '"' + "".join(escapes.get(ch, ch) for ch in name) + '"'


def build_data(config: dict, issues: list, pulls: list, repo: str) -> dict:
    aliases = {k.casefold(): v for k, v in config["aliases"].items()}
    excludes = {x.casefold() for x in config["exclude"]}
    excludes.add(repo.split("/")[0].casefold())  # owner never self-credits

    def display(login: str | None) -> str | None:
        if not isinstance(login, str) or not login.strip():
            return None
        login = login.strip()
        if login.casefold() in excludes or login.casefold().endswith("[bot]"):
            return None
        shown = safe_display(aliases.get(login.casefold(), login))
        return shown if shown.casefold() not in excludes else None

    contributors = Counter()
    for pr in pulls:
        if not isinstance(pr, dict) or not pr.get("merged_at"):
            continue
        author = pr.get("user") or {}
        if author.get("type") == "Bot":
            continue
        name = display(author.get("login"))
        if name:
            contributors[name] += 1

    hunters = Counter()
    for issue in issues:
        if not isinstance(issue, dict) or "pull_request" in issue:
            continue
        if issue.get("state") != "closed" or issue.get("state_reason") == "not_planned":
            continue
        labels = {x["name"].casefold() for x in issue.get("labels", [])
                  if isinstance(x, dict) and isinstance(x.get("name"), str)}
        if not {"bug", "verified-fix"}.issubset(labels) or labels & BAD_LABELS:
            continue
        author = issue.get("user") or {}
        if author.get("type") == "Bot":
            continue
        name = display(author.get("login"))
        if name:
            hunters[name] += 1

    def sorted_counts(items: Counter, field: str) -> list[dict]:
        return [{"name": name, field: count} for name, count in
                sorted(items.items(), key=lambda pair: (-pair[1], pair[0].casefold()))]

    thanks = []
    seen = set()
    for raw in config["special_thanks"]:
        name = display(raw)
        if name and name.casefold() not in seen:
            thanks.append(name)
            seen.add(name.casefold())
    ideas = []
    for item in config["ideas"]:
        name = display(item["name"])
        if name:
            ideas.append({"name": name, "ref": item["ref"]})
    return {
        "contributors": sorted_counts(contributors, "prs"),
        "bugHunters": sorted_counts(hunters, "reports"),
        "ideas": ideas,
        "specialThanks": thanks,
    }


def lua_render(data: dict) -> str:
    out = [
        "-- Generated from verified GitHub activity and community/credits.json.",
        "-- Do not edit this file manually. No live GitHub request occurs in WoW.",
        "local _, ns = ...",
        "ns.CommunityCredits = {",
    ]
    for section in ("contributors", "bugHunters", "ideas", "specialThanks"):
        out.append(f"    {section} = {{")
        for item in data[section]:
            if isinstance(item, str):
                out.append(f"        {render_lua_string(item)},")
            else:
                part = [f"name = {render_lua_string(item['name'])}"]
                for key in ("prs", "reports", "ref"):
                    if key in item:
                        part.append(f"{key} = {int(item[key])}")
                out.append("        { " + ", ".join(part) + " },")
        out.append("    },")
    out.append("}")
    return "\n".join(out) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY", DEFAULT_REPO))
    parser.add_argument("--config", type=Path, default=CONFIG)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--fixture", type=Path, help="Local deterministic fixture for tests; never use for releases")
    args = parser.parse_args(argv)
    conf = config_load(args.config)
    if args.fixture:
        fixture = json.loads(args.fixture.read_text(encoding="utf-8"))
        issues, pulls = fixture["issues"], fixture["pulls"]
    else:
        token = os.environ.get("GITHUB_TOKEN", "")
        issues = github_pages(args.repo, "issues", token)
        pulls = github_pages(args.repo, "pulls", token)
    credits = build_data(conf, issues, pulls, args.repo)
    rendered = lua_render(credits)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    if not args.output.exists() or args.output.read_text(encoding="utf-8") != rendered:
        args.output.write_text(rendered, encoding="utf-8", newline="\n")
    print("Credits generated: " + ", ".join(
        f"{k}={len(v)}" for k, v in credits.items()))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, RuntimeError, KeyError, OSError) as exc:
        print(f"Community generation aborted: {exc}", file=sys.stderr)
        sys.exit(1)
