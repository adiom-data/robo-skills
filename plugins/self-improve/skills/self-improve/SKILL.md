---
name: self-improve
description: Reflect on session learnings and create/update skills in the robo-skills repository. Use at the end of a session to capture new knowledge as reusable skills.
---

# Self-Improve Meta-Skill

Reflect on what was learned during the current session and contribute improvements to the skills repository.

## When to Use

- At the end of a productive session where new patterns or knowledge were discovered
- When you've solved a problem that required research or discovery
- When existing skills are missing information or could be improved
- User explicitly asks to capture learnings

## Process

### Step 1: Reflection

Ask yourself:
1. What new things did I learn in this session?
2. What problems did I solve that required research or discovery?
3. What existing skills were missing information I had to find elsewhere?
4. What patterns or commands could be reused in future sessions?

### Step 2: Identify Skill Updates

For each learning, determine:
- **New Skill**: Does this warrant a completely new skill?
- **Skill Update**: Does this improve an existing skill?
- **Not Applicable**: Is this too specific or one-off to be useful?

### Step 3: Create Update Files

For each skill that needs to be created or updated, create a markdown file in `/tmp/skill-updates/` with:

**Filename format**: `<skill-name>-update.md`

**Content format**:
```markdown
# Skill Update: <skill-name>

## Type: [CREATE | UPDATE]

## Description
Brief description of what this update adds or changes.

## Changes

### For CREATE - Full skill content:
[Complete SKILL.md content and any additional files]

### For UPDATE - Diff-style changes:
#### File: <filename>
#### Section: <section name>
#### Action: [ADD | MODIFY | DELETE]

**Before** (if MODIFY/DELETE):
```
[existing content]
```

**After** (if ADD/MODIFY):
```
[new content]
```

## Rationale
Why this change improves the skill.
```

### Step 4: Create PRs

For each update file created, execute:
```bash
droid exec "Use the file /tmp/skill-updates/<skill-name>-update.md to create a PR in git@github.com:adiom-data/robo-skills.git to create or update skill(s)"
```

## Example Session

After a session where you learned new MongoDB connection string patterns:

1. Create `/tmp/skill-updates/dsync-runner-update.md`:
```markdown
# Skill Update: dsync-runner

## Type: UPDATE

## Description
Add MongoDB Atlas SRV connection string format and password encoding notes.

## Changes

### File: SKILL.md
### Section: Supported Connectors
### Action: MODIFY

**Before**:
- **MongoDB**: `mongodb://user:pass@host:27017/db`

**After**:
- **MongoDB**: `mongodb://user:pass@host:27017/db`
- **MongoDB Atlas**: `mongodb+srv://user:pass@cluster.mongodb.net/db` (URL-encode special chars in password)

## Rationale
Atlas SRV format is commonly used and password encoding is a frequent gotcha.
```

2. Execute:
```bash
droid exec "Use the file /tmp/skill-updates/dsync-runner-update.md to create a PR in git@github.com:adiom-data/robo-skills.git to create or update skill(s)"
```

## Guidelines

- Only create updates for genuinely reusable knowledge
- Keep updates focused and atomic (one concept per update)
- Include rationale to help reviewers understand the value
- Test any commands or code snippets before including them
- Don't create skills for one-off or highly specific scenarios
