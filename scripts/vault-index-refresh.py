#!/usr/bin/env python3
"""
vault-index-refresh.py — Regenerate category INDEX.md files from skill folders.

Walks all category folders under skills/ and generates an INDEX.md
in each category listing the skills and their descriptions.

Usage: python3 scripts/vault-index-refresh.py
"""

import json
import os
from pathlib import Path
from datetime import date

VAULT_ROOT = Path(__file__).parent.parent
SKILLS_DIR = VAULT_ROOT / "skills"

SKIP_DIRS = {"_registry", "_archive", "_obsolete", "_experiments", "_templates"}

def get_skill_summary(skill_dir: Path) -> dict:
    meta_path = skill_dir / "metadata.json"
    readme_path = skill_dir / "README.md"

    meta = {}
    if meta_path.exists():
        try:
            with open(meta_path) as f:
                meta = json.load(f)
        except Exception:
            pass

    description = "No description available."
    if readme_path.exists():
        try:
            lines = open(readme_path).readlines()
            # Find "## What it does" section
            for i, line in enumerate(lines):
                if "## What it does" in line:
                    for next_line in lines[i+1:]:
                        next_line = next_line.strip()
                        if next_line and not next_line.startswith("#"):
                            description = next_line
                            break
                    break
        except Exception:
            pass

    return {
        "slug": meta.get("slug", skill_dir.name),
        "name": meta.get("name", skill_dir.name),
        "version": meta.get("version", "v1"),
        "status": meta.get("status", "active"),
        "description": description,
        "featured": meta.get("featured", False),
    }

def main():
    for category_dir in sorted(SKILLS_DIR.iterdir()):
        if not category_dir.is_dir():
            continue
        if category_dir.name in SKIP_DIRS:
            continue

        category = category_dir.name
        skills = []

        for skill_dir in sorted(category_dir.iterdir()):
            if skill_dir.is_dir():
                skills.append(get_skill_summary(skill_dir))

        if not skills:
            continue

        lines = [
            f"# {category.replace('-', ' ').title()} Skills\n",
            f"\n_Last updated: {date.today()}_\n\n",
            "| Skill | Description | Version | Status |\n",
            "|-------|-------------|---------|--------|\n",
        ]

        for s in skills:
            status_badge = "✅ active" if s["status"] == "active" else s["status"]
            featured = " ⭐" if s["featured"] else ""
            lines.append(
                f"| [{s['name']}{featured}]({s['slug']}/) "
                f"| {s['description']} "
                f"| {s['version']} "
                f"| {status_badge} |\n"
            )

        index_path = category_dir / "INDEX.md"
        with open(index_path, "w") as f:
            f.writelines(lines)

        print(f"Written: {index_path} ({len(skills)} skills)")

if __name__ == "__main__":
    main()
