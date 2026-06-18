# AGENTS.md — Contributing skills to this repo

This repo is a **marketplace of plugins**. Each plugin ships one skill that an AI
coding assistant (Claude, Codex, Droid, etc.) can load on demand. This guide is the
canonical reference for adding a new skill. Follow it exactly — the layout and the
manifests are convention-driven, and a skill is only discoverable if every piece is
present.

## Repository layout

```
robo-skills/
├── README.md                       # Human-facing catalog (table of plugins)
├── AGENTS.md                       # This guide
├── .claude-plugin/marketplace.json # Marketplace catalog (Claude) — lists every plugin
├── .factory-plugin/marketplace.json# Marketplace catalog (Factory) — kept identical to the above
└── plugins/
    └── <plugin-name>/
        ├── .factory-plugin/plugin.json          # Plugin manifest
        └── skills/<plugin-name>/
            ├── SKILL.md                          # Required: skill definition + instructions
            ├── checklists.md                     # Optional: verification checklists
            ├── references.md                     # Optional: reference docs
            ├── schemas/                          # Optional: JSON schemas for input validation
            └── templates/                        # Optional: code/config templates
```

Conventions:
- The **plugin directory name, the plugin `name`, the skill directory name, and the
  `name` in SKILL.md frontmatter are all the same kebab-case string.**
- `skills/<name>/SKILL.md` is the only required file inside a skill. Add
  `checklists.md`, `references.md`, `schemas/`, `templates/` only when the skill needs them.

## Steps to add a new skill

1. **Pick a kebab-case name**, e.g. `my-new-skill`. Use it everywhere below.

2. **Create the skill:**
   ```
   plugins/my-new-skill/skills/my-new-skill/SKILL.md
   ```
   Frontmatter is a YAML block with two fields:
   ```markdown
   ---
   name: my-new-skill
   description: One sentence on what it does, then "Use when …" describing the trigger.
   ---

   # Title

   Instructions for the agent…
   ```
   The `description` is what the assistant matches against to decide when to load the
   skill — lead with the capability and include the trigger conditions ("Use when …").

3. **Create the plugin manifest:**
   ```
   plugins/my-new-skill/.factory-plugin/plugin.json
   ```
   ```json
   {
     "name": "my-new-skill",
     "description": "Short description",
     "version": "1.0.0",
     "author": { "name": "Adiom" }
   }
   ```

4. **Register in BOTH marketplace catalogs** — add an identical entry to the `plugins`
   array in `.claude-plugin/marketplace.json` **and** `.factory-plugin/marketplace.json`.
   These two files must stay in sync.
   ```json
   {
     "name": "my-new-skill",
     "description": "Short description",
     "source": "./plugins/my-new-skill",
     "category": "data"
   }
   ```
   Categories currently in use: `data`, `docs`, `meta`, `migration`. Reuse an existing
   one when it fits; introduce a new category only when none does.

5. **Add a row to `README.md`** in the *Available Plugins* table:
   ```
   | [my-new-skill](plugins/my-new-skill) | Short description |
   ```

## Before you finish — checklist

- [ ] Plugin dir, plugin `name`, skill dir, and SKILL.md `name` all match (kebab-case).
- [ ] `SKILL.md` has valid frontmatter (`name`, `description`).
- [ ] `.factory-plugin/plugin.json` exists for the plugin.
- [ ] Entry added to **both** `marketplace.json` files, kept identical.
- [ ] `README.md` table row added.
- [ ] Every `.json` file is valid JSON, e.g.:
      ```bash
      for f in .claude-plugin/marketplace.json .factory-plugin/marketplace.json \
               plugins/*/.factory-plugin/plugin.json; do
        python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f" && echo "OK $f"
      done
      ```

## Notes

- `.factory-plugin/marketplace.json.example` is a generic Factory template (a different
  marketplace with sample plugins). It is **not** this repo's catalog — leave it alone.
- Installation for end users is documented in `README.md` (`npx skills add adiom-data/robo-skills`
  or copying a plugin folder into `~/.factory/skills/` / `.factory/skills/`).
