# Contributing

This is a personal Claude Code skill vault that is publicly available for reference and adoption. Direct contributions (pull requests to add or modify skills) are not the primary workflow here — the vault is maintained from a single Claude Code environment.

That said, there are ways to engage:

---

## Reporting issues

Use the [issue tracker](https://github.com/UltronCore/claude-skill-vault/issues) to:

- **Request a skill** — describe what you want Claude Code to do and what gap it fills
- **Report a safety issue** — if you find credentials, private paths, or personal data in any file
- **Report a broken skill** — if a skill's SKILL.md doesn't work as documented
- **Suggest an improvement** — structural, documentation, or workflow suggestions

---

## Adopting this system

The vault is designed to be forked and run as your own. To bootstrap your own vault:

```bash
git clone https://github.com/UltronCore/claude-skill-vault.git my-skill-vault
cd my-skill-vault

# Remove existing skills you don't want
# Import your own skills
scripts/vault-import.sh my-skill ~/.claude/skills/my-skill.md category-name

# Rebuild indexes
python3 scripts/vault-registry-refresh.py
python3 scripts/vault-index-refresh.py
```

Then push to your own repository and wire up the release workflow with your own `GITHUB_TOKEN`.

See [docs/repository-guidelines.md](docs/repository-guidelines.md) for the full setup guide.

---

## Commit conventions

If you fork and maintain your own vault, these conventions keep the changelog clean:

| Prefix | Use for |
|--------|---------|
| `feat:` | New skill added |
| `improve:` | Skill updated or optimized |
| `refactor:` | Reorganization without functional change |
| `chore:` | Registry refresh, index rebuild, metadata cleanup |
| `docs:` | Documentation changes |
| `fix:` | Broken script or workflow fix |

---

## Safety requirements

All content committed to any public fork must meet the standards in [docs/public-safety-policy.md](docs/public-safety-policy.md):

- No credentials, API keys, or tokens of any kind
- No private file paths (use `~/{path}` or `{user}` placeholders)
- No personal data, names, emails, or identifying information
- Run `scripts/vault-check.sh` on every skill folder before committing

---

## License

This repository is MIT licensed. You are free to use, adapt, and redistribute the skills and tooling.
