# Scripts

Helper automation for maintaining this Obsidian vault.

## Common commands

```bash
bash scripts/rollover-daily-todos.sh
bash scripts/update-person-last-met.sh
bash scripts/eod-rollover-and-giteod.sh
bash scripts/install-giteod-cron.sh 18:30
bash scripts/uninstall-giteod-cron.sh
python3 scripts/replace-tags.py --source old-tag --target new-tag
```

## Obsidian plugin install

```bash
bash scripts/install-obsidian-plugins.sh
```

This optional script downloads the tested community plugin versions listed in the root `README.md`.
You can also install the same plugins through Obsidian's Community plugins browser.

## End-of-day flow

`eod-rollover-and-giteod.sh` runs:

1. `rollover-daily-todos.sh` to move unfinished daily todos and priorities forward.
2. `update-person-last-met.sh` to refresh people-note `Last Met` fields from meeting logs.
3. `giteod.sh` to commit and push all vault changes with a timestamp message.

## Validation

After editing scripts, run:

```bash
bash -n scripts/*.sh
python3 -m py_compile scripts/replace-tags.py
```
