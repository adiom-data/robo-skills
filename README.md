# Robo Skills Marketplace

A collection of AI-powered skills (plugins) for Factory Droid.

## Available Plugins

| Plugin | Description |
|--------|-------------|
| [dsync-sqlbatch-mapping](plugins/dsync-sqlbatch-mapping) | Generate SQLBatch dsync YAML configuration for SQL to NoSQL data sync |

## Installation

Copy any plugin folder to your Factory skills directory:

```bash
# Personal skills
cp -r plugins/<plugin-name> ~/.factory/skills/

# Project-specific skills
cp -r plugins/<plugin-name> .factory/skills/
```

## Plugin Structure

Each plugin follows the standard Factory skill format:

```
plugin-name/
├── SKILL.md          # Main skill definition and instructions
├── checklists.md     # Verification checklists (optional)
├── references.md     # Reference documentation (optional)
├── schemas/          # JSON schemas for input validation (optional)
└── templates/        # Code/config templates (optional)
```
