# Obsidian Notes Starter Vault

A generic, shareable Obsidian vault for daily notes, project tracking, people notes, references, dashboards, and lightweight Git automation.

This repo is a sanitized starter version of a working notes practice: it preserves the folder structure, templates, Dataview dashboards, task workflow, and helper scripts while using only mock content.

## Folder layout

| Path | Purpose |
| --- | --- |
| `0_templates/` | Obsidian/Templater templates for daily, project, people, reference, master todo, and weekly review notes. |
| `1_daily/` | Daily notes named `YYYY-MM-DD.md`. |
| `2_projects/` | Project notes with frontmatter and decision/task sections. |
| `3_people/` | People notes with meeting logs and mention queries. |
| `4_mastertracker/` | Cross-cutting task tracker. |
| `5_reference/` | Durable reference notes and playbooks. |
| `_dashboards/` | Dataview dashboards. Start with `_dashboards/Overview.md`. |
| `_artifacts/` | Attachments/exports. Ignored by default except `.gitkeep`. |
| `scripts/` | Automation for rollover, Git sync, tag replacement, cron, and plugin install. |

## Required Obsidian setup

Open this folder as an Obsidian vault, then enable community plugins when prompted.

### Core plugins

The vault expects these built-in Obsidian plugins to be enabled:

- Daily notes
- Templates
- Graph view
- Backlinks / outgoing links
- Page preview
- Command palette
- Properties
- Bookmarks

The committed `.obsidian/core-plugins.json` enables these by default.

### Community plugins

The vault uses these community plugins:

| Plugin | ID | Tested version | Used for |
| --- | --- | --- | --- |
| Calendar | `calendar` | `1.5.10` | Calendar navigation for daily notes. |
| Dataview | `dataview` | `0.5.68` | Dashboard tables, task views, and dynamic mention/idea queries. |
| Tasks | `obsidian-tasks-plugin` | `7.22.0` | Rich task syntax and task status support. |
| Templater | `templater-obsidian` | `2.16.2` | Dynamic templates (`tp.date`, `tp.file.title`, cursor placement). |

Plugin settings are committed under `.obsidian/plugins/*/data.json`. Plugin runtime files (`main.js`, `styles.css`) are ignored so the repo stays small and avoids vendoring third-party releases.

## Installing plugins

### Option A: Obsidian UI

1. Open **Settings → Community plugins**.
2. Turn off **Restricted mode** if prompted.
3. Search for and install: Calendar, Dataview, Tasks, and Templater.
4. Enable all four plugins.
5. Confirm Templater's template folder is `0_templates`.

### Option B: helper script

From the repo root:

```bash
bash scripts/install-obsidian-plugins.sh
```

Use `--force` to overwrite already-downloaded plugin runtime files:

```bash
bash scripts/install-obsidian-plugins.sh --force
```

The script requires `curl` and internet access. It downloads the tested plugin release assets into `.obsidian/plugins/`.

## Daily workflow

1. Open or create today's daily note in `1_daily/`.
2. Capture priorities, meetings, notes, ideas, and todos.
3. Use `#idea` for ideas and `#decision` for decisions so dashboard queries can find them.
4. Promote longer-running work into `2_projects/`.
5. Add meeting context to `3_people/` notes.
6. Use `_dashboards/Overview.md` for a roll-up view.

## Automation

### Rollover daily todos

Move unfinished todos and priorities from one daily note to another:

```bash
bash scripts/rollover-daily-todos.sh
```

With explicit dates:

```bash
bash scripts/rollover-daily-todos.sh 2026-08-02 2026-08-01
```

### Update people notes

Refresh each `3_people/*.md` `Last Met` field from the first dated entry under `## 🗓 Meeting Log`:

```bash
bash scripts/update-person-last-met.sh
```

### End-of-day Git sync

Run rollover, update people notes, then commit and push:

```bash
bash scripts/eod-rollover-and-giteod.sh
```

Install a daily cron entry, for example at 18:30:

```bash
bash scripts/install-giteod-cron.sh 18:30
```

Remove it:

```bash
bash scripts/uninstall-giteod-cron.sh
```

### Replace tags safely

Preview a tag rename:

```bash
python3 scripts/replace-tags.py --source old-tag --target new-tag
```

Apply it:

```bash
python3 scripts/replace-tags.py --source old-tag --target new-tag --apply
```

## Validation

After changing scripts:

```bash
bash -n scripts/*.sh
python3 -m py_compile scripts/replace-tags.py
```

After changing dashboard queries, open `_dashboards/Overview.md` in Obsidian and confirm Dataview renders without errors.
