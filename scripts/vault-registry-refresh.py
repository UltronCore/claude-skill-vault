#!/usr/bin/env python3
"""
vault-registry-refresh.py — Regenerate registry.json from skill folders.

Walks all category folders under skills/ and reads each skill's metadata.json
to rebuild the central registry.

Usage: python3 scripts/vault-registry-refresh.py
"""

import json
import os
from pathlib import Path
from datetime import date

VAULT_ROOT = Path(__file__).parent.parent
SKILLS_DIR = VAULT_ROOT / "skills"
REGISTRY_DIR = SKILLS_DIR / "_registry"

SKIP_DIRS = {"_registry", "_archive", "_obsolete", "_experiments", "_templates"}

def load_metadata(skill_dir: Path) -> dict | None:
    meta_path = skill_dir / "metadata.json"
    if not meta_path.exists():
        return None
    try:
        with open(meta_path) as f:
            return json.load(f)
    except Exception as e:
        print(f"  WARN: Could not read {meta_path}: {e}")
        return None

def main():
    registry = []
    categories_map: dict[str, list] = {}

    for category_dir in sorted(SKILLS_DIR.iterdir()):
        if not category_dir.is_dir():
            continue
        if category_dir.name in SKIP_DIRS:
            continue

        category = category_dir.name
        categories_map[category] = []

        for skill_dir in sorted(category_dir.iterdir()):
            if not skill_dir.is_dir():
                continue

            meta = load_metadata(skill_dir)
            if meta is None:
                print(f"  SKIP: No metadata.json in {skill_dir}")
                continue

            entry = {
                "name": meta.get("name", skill_dir.name),
                "slug": meta.get("slug", skill_dir.name),
                "version": meta.get("version", "v1"),
                "status": meta.get("status", "active"),
                "path": f"skills/{category}/{skill_dir.name}",
                "updated": meta.get("updated", str(date.today())),
                "source": meta.get("source", "unknown"),
                "category": category,
                "tags": meta.get("tags", []),
                "public_safe": meta.get("public_safe", True),
                "featured": meta.get("featured", False),
            }
            registry.append(entry)
            categories_map[category].append(entry["slug"])

    # Write registry.json
    registry_path = REGISTRY_DIR / "registry.json"
    with open(registry_path, "w") as f:
        json.dump({"updated": str(date.today()), "skills": registry}, f, indent=2)
    print(f"Written: {registry_path} ({len(registry)} skills)")

    # Write categories.json
    categories_path = REGISTRY_DIR / "categories.json"
    with open(categories_path, "w") as f:
        json.dump({"updated": str(date.today()), "categories": categories_map}, f, indent=2)
    print(f"Written: {categories_path}")

    # Write featured.json
    featured = [s for s in registry if s.get("featured")]
    featured_path = REGISTRY_DIR / "featured.json"
    with open(featured_path, "w") as f:
        json.dump({"updated": str(date.today()), "featured": featured}, f, indent=2)
    print(f"Written: {featured_path} ({len(featured)} featured skills)")

if __name__ == "__main__":
    main()
