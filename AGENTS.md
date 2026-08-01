# Repository Guidelines

## Project Structure

This is an Obsidian vault, not an application build repo.

- `0_templates/`: reusable note templates.
- `1_daily/`: daily notes named `YYYY-MM-DD.md`.
- `2_projects/`: project notes.
- `3_people/`: people notes and meeting logs.
- `4_mastertracker/`: master task tracking.
- `5_reference/`: durable references.
- `_dashboards/`: Dataview dashboards.
- `scripts/`: helper automation.

## Style

- Keep content generic and safe to share.
- Use lowercase kebab-case filenames except daily notes.
- Prefer relative Obsidian links.
- Do not commit secrets, personal data, private URLs, or third-party plugin runtime files.

## Validation

- Run `bash -n scripts/*.sh` after shell script edits.
- Run `python3 -m py_compile scripts/replace-tags.py` after Python script edits.
- Preview changed Markdown and dashboard queries in Obsidian when possible.
