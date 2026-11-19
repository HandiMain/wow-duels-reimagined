# Duels Reimagined — Project Guide

This document is for work in progress. It records the agreed direction and prevents ideas from being mistaken for finished features.

## Current state

- **Phase:** Visual design exploration (IDEA)
- **Addon source:** Not started
- **Build authorization:** Not granted
- **Live game verification:** None
- **Target clients:** World of Warcraft: Forever and Retail (planned; compatibility must be checked separately)

The first task is to explore and approve an original overall interface identity. No screen, system, or visual concept has been approved yet.

## Branches

- `main`: Player-facing project page and approved, stable work only.
- `develop`: Current designs, notes, and eventually implementation/testing after explicit authorization.
- Both branches are **public**. Do not store secrets, private records, test-player personal data, or unlicensed assets in either branch.
- Do not merge to `main`, tag a version, or publish a release without explicit approval.

## Approval states

1. **IDEA** — Being discussed. No commitment to build.
2. **CONCEPT APPROVED** — Appearance, visible behavior, and scope agreed.
3. **BUILD AUTHORIZED** — Implementation explicitly requested.
4. **IMPLEMENTED / UNTESTED** — Written, but not yet proven in the game.
5. **VERIFIED** — Relevant checks and required in-game tests have passed. Multiplayer claims require real multiplayer tests.

Visual approval is not permission to implement.

## Unified systems and cross-feature compatibility

Every approved feature must cooperate with the existing addon, not form a separate mini-addon. Keep one owner for each shared concern (settings, themes, animation, data, events, networking, and diagnostics) and reuse that owner's public interface from individual features.

Before modifying a feature, inspect its callers, shared UI, Options, event lifecycle, data storage, client-specific paths, and nearby behavior. Confirm that theme and font changes update all applicable existing and future controls. Preserve chat focus, Escape, combat safety, and clean open/close behavior. Avoid duplicates and redundant adapters. Test neighboring behavior after each focused change, and do not call integration verified without in-game evidence.

## Before implementation

For each approved feature, agree on its player purpose, visible interface, interactions, empty and error states, settings, game API limits, exclusions, dependencies, and tests. Prefer one focused behavior change at a time.

Build for clear, WoW-native controls, safe Blizzard chat/input behavior, a central Options area, predictable window focus and combat-safe interaction. Keep responsibilities separated; avoid duplicate engines or settings owners.

## Reference research

Inspect relevant **Polestar** source and behavior first whenever it is accessible. Then review **EllesmereUI**, **Horizon Suite**, and **BurstFX** when useful. References inform decisions; they do not determine our identity or roadmap.

Respect upstream license requirements and original attribution for any reused material. Check the actual source, permissions, and compatibility before adapting code or artwork. Never present uninspected behavior as verified.

## Feature candidates — not promises

Past experiments included duel history, personal statistics, rankings, player profiles, rivalries, community, tournaments, achievements, communication, and War Games organization. Every candidate needs separate design and feasibility approval. None is committed to implementation by appearing here.

## Verification and reporting

- Validate client differences between Forever and Retail before claiming support.
- Do not invent ranking, synchronization, matchmaking, tournament results, or verified match evidence.
- Clearly distinguish **LOCAL**, **MANUAL**, **SIMULATED**, **ESTIMATED**, and **NOT OBSERVED** data when applicable.
- Automated checks and mock tests do not prove WoW gameplay.
- Report what changed, why, test evidence, required in-game checks, and remaining uncertainty.
- Prefer focused changes with checks for nearby behavior and regressions.

## Decisions — November 18, 2026

- Rebuild the addon from zero. Earlier prototypes are learning references, not a code baseline.
- Stay in visual design until the appearance and behavior are approved; implementation needs separate authorization.
- Both GitHub branches are public, with `main` reserved for approved, stable work.
- Public-facing descriptions should be written clearly for players. Technical working notes belong on `develop`.
- No automatic releases, surprise features, or unverified claims.
