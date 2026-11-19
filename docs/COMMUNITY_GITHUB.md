# Duels Reimagined — Community and GitHub

GitHub only for now; Discord integrations are deliberately out of scope.

## What the Community page will show

Four equally important categories, designed for the Duels Reimagined UI:

- **Contributors** — people whose GitHub pull requests were merged. Count only merged PRs, never open, draft, rejected or bot PRs.
- **Bug Hunters** — people whose **closed bug issues** carry both `bug` and the maintainer-applied `verified-fix` labels. A completed issue without verified-fix is **not** a credited fix. Exclude duplicates, invalid, stale, needs-info and not-planned issues.
- **Community Ideas** — people whose ideas actually shipped, listed manually in `community/credits.json` with their issue or PR reference. A submitted idea alone never counts.
- **Special Thanks** — carefully curated names in `community/credits.json`.

Zero names is a valid state. No placeholder names, sample statistics, simulated people or invented proof of code contributions are shipped. The file `addon/DuelsReimagined/Community/Credits.lua` is generated before packaging; the game does not make web requests.

## GitHub issue forms

The forms in `.github/ISSUE_TEMPLATE/` are prepared on **develop**:

- [Report a bug](https://github.com/HandiMain/wow-duels-reimagined/issues/new?template=bug-report.yml)
- [Suggest an idea](https://github.com/HandiMain/wow-duels-reimagined/issues/new?template=feature-request.yml)

**Important:** GitHub serves issue forms from the repository's default branch (`main`). Until the approved templates are promoted to main, those links might show a blank/new issue form instead of our custom questions. Never tell players that a report is filed merely because they copied a link. WoW addons cannot send GitHub Issues or open external URLs on their own: the Community UI will present a **selectable link to copy with Ctrl+C**; the player submits in a browser while logged in.

## Verified bug workflow

1. Player submits a `bug` issue using the form.
2. Maintainer reproduces and resolves it. Close the issue as **Completed**, not as Duplicate/Not planned.
3. Only when the relevant fix is actually verified and shipped, apply label **`verified-fix`**. Create that label in the repository's GitHub **Issues → Labels** menu if it does not already exist.
4. The credits generator will then count that issue for its original reporter. Do **not** label an open issue as verified credit, and do not count a suggestion as a bug.
5. To omit an identity (including by request), add it to `exclude`. `aliases` overrides the public display text, and `special_thanks`/`ideas` stay human-curated.

## Generator and automation

`python3 -m unittest discover -s tools/community -p 'test_*.py' -v`

`GITHUB_TOKEN=<read-only GitHub token> python3 tools/community/generate_credits.py`

The generator uses Python's standard library and the GitHub REST API. It fetches all pages of issues/PRs, validates and filters them, resolves aliases/exclusions, and writes reproducible Lua. If GitHub fails or pagination becomes incomplete it **fails without replacing the previously generated file**. This is a build-time operation; the in-game addon has no token, Internet API or community SavedVariables.

The `.github/workflows/community-credits.yml` workflow runs on relevant `develop` pushes. Once the workflow is **explicitly approved and promoted to main**, issue events, merged PRs and its weekly schedule can trigger it; its output is committed **only to develop** and never auto-published to main. No new branches, PRs or releases are created. The repository may need GitHub Actions enabled and workflow token write access for direct credits commits. Check branch rules if pushes are rejected.

Do not merge to `main` automatically. Test the workflow and review generated identities before release. No automatic rewards, money, rankings, or player data are ever derived from GitHub Issues.
