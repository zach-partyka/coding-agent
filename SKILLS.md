# Ralph skills – single source

> **Using Ralph on your project?** You don't need this doc — `setup.sh` installs skills automatically. This is for people maintaining the skills themselves. See `README.md` for user docs.

Ralph’s slash-command skills (**/ralph**, **/ralph-plan**, **/ralph-continuous**, **/ralph-archive**) are **not** shipped in this repo. They are maintained in one place and installed into Claude’s skills directory.

## Single source: the skills repo → `~/.claude/skills/`

- **Canonical source:** A separate repo (e.g. `ralph-skills`) on GitLab and/or GitHub.
- **Runtime:** Claude loads skills from **`~/.claude/skills/`**.
- **This repo (ralph-starter-kit):** Scripts, templates, and docs only. It **references** the skills repo and installs from it.

So you maintain **one** set of skills (in the ralph-skills repo); GitLab/GitHub ralph-starter-kit only points at that repo and runs the install script.

## Install skills (users)

From the Ralph kit directory, or from any project after setup:

```bash
/path/to/Ralph/kit/scripts/install-ralph-skills.sh
```

Default: clones `https://gitlab.zgtools.net/tpm_cdp_team/ralph-skills.git` into `~/.claude/skills/`. To use a different repo (e.g. GitHub):

```bash
/path/to/Ralph/kit/scripts/install-ralph-skills.sh https://github.com/YOUR_ORG/ralph-skills.git
```

Setup (`setup.sh`) runs this for you when you configure a project.

## One-time: create the skills repo (maintainers)

If the ralph-skills repo doesn’t exist yet:

1. Create empty repos:
   - GitLab: `https://gitlab.zgtools.net/tpm_cdp_team/ralph-skills`
   - GitHub: `https://github.com/YOUR_ORG/ralph-skills` (optional mirror)

2. Put the four skill directories in that repo (top level):
   - `ralph/`
   - `ralph-plan/`
   - `ralph-continuous/`
   - `ralph-archive/`  
   Each must contain a `SKILL.md` (and any other files you use).

3. Populate the ralph-skills repo with the four skill directories. If this repo had skills before they were removed, recover from git history:
   ```bash
   git clone https://gitlab.zgtools.net/tpm_cdp_team/ralph-starter-kit.git ralph-temp
   cd ralph-temp
   git checkout <commit-before-skills-removal>   # or the commit that still has Ralph/skills/
   mkdir -p /path/to/ralph-skills-repo
   cp -r Ralph/skills/* /path/to/ralph-skills-repo/
   cd /path/to/ralph-skills-repo
   git add . && git commit -m "Add Ralph skills" && git push origin main
   ```
   Then add the GitHub remote and push if you use both.

4. Point ralph-starter-kit at the new repo (see above); users run `install-ralph-skills.sh` or setup.

## Summary

| What              | Where |
|-------------------|--------|
| Single set of skills | ralph-skills repo (GitLab/GitHub) |
| Claude loads from | `~/.claude/skills/` |
| ralph-starter-kit | No skills; references skills repo and runs `install-ralph-skills.sh` |
